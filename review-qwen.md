# Plan Review: zig-api.md

## Executive Summary

The plan is well-structured and close to idiomatic Zig design. The biggest risks are API consistency, memory ownership clarity, and unverified Zig 0.16 std API signatures — not endpoint logic.

**Top issues to fix before implementation:**

1. **(Critical)** Pick one public API shape and use it everywhere (`README` currently conflicts with plan).
2. **(Critical)** Standardize memory ownership/deinit pattern (currently inconsistent, especially `HttpResponse.deinit(allocator)`).
3. **(Critical)** Choose one error strategy as default (`!T` vs `ApiResult(T)`), not both.
4. **(Important)** Add compile-spike milestone to validate exact Zig 0.16 std APIs used in signatures.
5. **(Important)** Expand chat types or add escape hatch fields to avoid immediate incompatibility.

---

## 1) API Design Issues

### Critical — README vs plan mismatch

- `README.md:62` uses `client.chat(...)`
- `zig-api.md:53` uses `client.chat.completions.create(...)`

This is a major ergonomics/documentation conflict and will confuse early adopters.

**Recommendation:**
- Make **one canonical API** for v0.1.0: `client.chat.completions.create(...)` (more extensible, consistent with other resources).
- If convenience sugar is wanted later, add `client.chat.create(...)` as an alias, but keep one style in docs/tests.

### Important — Namespace object lifetime/layout unresolved

Plan says "decide exact resource namespace storage layout" (`zig-api.md:969`) but exposes namespace-first API already.

**Recommendation:**
- Use lightweight value namespaces holding `*Client`:
  - `client.chat` (struct with `client: *Client`)
  - `chat.completions` (same pattern)
- Keep it zero-allocation and initialized in `Client.init`.

### Minor — Naming consistency

- `x_title` in config maps to `X-Title`; good.
- `http_referer` maps to `HTTP-Referer`; good.
- Keep request field names API-compatible, but expose Zig names in structs where needed and map in JSON layer.

---

## 2) Zig 0.16.x Compatibility Review

Zig `0.16.0` is installed (confirmed). The plan is directionally aligned with 0.16 IO model, but there are **verify-now** items:

### Important — `std.Io` / `std.Io.Threaded` exact API signatures

The plan assumes:
- `var threaded: std.Io.Threaded = .init_single_threaded;`
- `threaded.io()`
- `Client.init(..., io: std.Io, ...)`

These are plausible for 0.16, but std APIs changed rapidly across dev cycles. Treat these as **must compile-check prototypes** before locking public signatures.

### Important — `std.http.Client` constructor/fields

Plan states `std.http.Client` initialized with `.allocator` and `.io` (`zig-api.md:186,248`). Verify exact init surface in 0.16.0 (field names/method names may differ).

### Minor — JSON option names

`emit_null_optional_fields` and `ignore_unknown_fields` should be compile-verified against 0.16 JSON API naming.

**Recommendation:**
- Add Milestone 0.5 "compile spike":
  1. Minimal `Client.init` with `std.Io` + `std.http.Client`
  2. One GET request to a fake local endpoint
  3. One `std.json` encode/decode roundtrip
- Only then freeze API signatures.

---

## 3) Memory Management Review

### Critical — Inconsistent deinit contract

`HttpResponse.deinit(self, allocator)` (`zig-api.md:326`) conflicts with other deinits that take only `self`.

This inconsistency will create mistakes and awkward APIs.

**Recommendation (pick one and enforce globally):**
1. **Preferred:** Owning structs store allocator and expose `deinit(self)` only.
2. Alternative: Every owning deinit takes allocator (less ergonomic, more error-prone).

### Important — High risk of double-free/partial-free with JSON trees

Types like `CompletionResponse`, `ListResponse`, `CompletionChunk` contain nested slices. If each nested field is independently freed, bugs are likely.

**Recommendation:**
- For each response/chunk, allocate via an internal arena:
  - Store `arena: std.heap.ArenaAllocator` in response object
  - Parsed strings/slices live in arena
  - `deinit` only deinits arena (single free path)
- This dramatically simplifies ownership and avoids nested free logic.

### Important — Stream chunk lifecycle may be allocation-heavy

`stream.next() -> !?CompletionChunk` plus `chunk.deinit()` per chunk can produce heavy churn.

**Recommendation:**
- Decide between:
  - **Owned chunks** (current plan): easiest API, more alloc/free.
  - **Borrowed chunk view valid until next call**: faster, trickier lifetime.
- For v0.1.0, owned chunks are acceptable, but document perf tradeoff.

---

## 4) Milestone Ordering

Current order is mostly good, but some reordering is warranted:

### Important reorder

- Move **transport mockability decision** from checklist into early milestones (before Models API).
- Move **Error handling + Retry** to be designed before first endpoint implementation (or at least before chat).
- Move **Pagination** out of v0.1.0 path unless a required endpoint needs it.

### Suggested sequence

`0 setup → 1 core client → 2 options → 3 HTTP transport abstraction + mockability → 4 JSON → 5 errors → 6 retry → 7 models → 8 chat create → 9 stream → 10 tests/docs polish`

---

## 5) Type Design Completeness vs OpenRouter

### Important — Chat request/response too narrow

Current `Message` only supports `content: []const u8` (`zig-api.md:585-588`), which is insufficient for modern chat APIs.

Likely-needed fields (at least optional):
- `name`
- `tool_calls` / `tool_call_id`
- Multimodal content parts (text/image)
- Provider routing / transforms / response_format
- `seed`, `frequency_penalty`, `presence_penalty`, `logprobs`, `top_logprobs`
- `max_tokens` vs possible newer token field compatibility

### Important — finish_reason should be enum+unknown

`finish_reason: ?[]const u8` works but is weakly typed.

**Recommendation:**
- Use tagged enum with fallback unknown string storage (or plain string for v0.1 but document).

### Minor — Usage fields may be optional/extended

Keep `Usage` fields optional or tolerate unknown additions robustly.

### Minor — Embeddings `input` may need token-array form

Plan includes string and string[] only. Some APIs allow token arrays; consider deferring but note as future extension.

---

## 6) Error Handling Strategy (`!T` vs `ApiResult(T)`)

### Critical — Dual strategy is confusing

Mixing thrown errors and `ApiResult` will force users to handle both paradigms inconsistently.

**Recommendation:**
Use **`!T` as primary public API** and represent API HTTP failures as a typed error union entry plus retrievable detail.

Two clean patterns:
1. `!T` with error set + `client.last_api_error` (not ideal for threads), or
2. `!T` where error payload is returned via dedicated error type object at boundary.

For Zig ergonomics:
- Transport/parse errors as error set
- API non-2xx as `error.ApiError`
- Methods that need details return a small wrapper containing `T` or `ApiError` **internally**, then adapt to consistent public style.

But pick one style publicly.

---

## 7) Streaming Design (SSE + iterator)

### Important — Parser spec needs tightening

Current SSE bullets are good but incomplete:
- Handle multiple `data:` lines per event (concatenate with `\n`)
- Ignore `event:` and `id:` safely
- Handle CRLF and LF line endings
- Enforce max line/event size limits (DoS safety)

### Important — Early-exit behavior

`stream.deinit()` must close request/response cleanly when user breaks early. Define whether `next()` after done returns `null` always and whether repeated deinit is safe.

### Minor — Error semantics

Differentiate:
- Malformed SSE frame
- Malformed JSON payload
- Upstream closed unexpectedly
- User cancellation (`error.Canceled`)

---

## 8) Missing Considerations

### Important

- **Transport abstraction for tests**: Define a minimal internal interface now; don't bind all logic to `std.http.Client` calls directly.
- **Thread safety policy**: Explicitly document `Client` is not thread-safe unless externally synchronized (plan hints this; make explicit in API docs).
- **Rate-limit metadata**: Expose headers (e.g., reset/remaining/request-id). Even if not first-class fields, provide response metadata hook.
- **Observability hook**: Optional debug callback for request/response metadata with auth redaction.

### Minor

- **Versioning/User-Agent strategy**: Derive from package version once, not hand-maintained string.
- **Idempotency/key headers**: Optional request header pass-through is enough for now.
- **Provider-specific params**: Add `extra_body`/`provider` escape hatch so users aren't blocked by missing typed fields.
- **Tool/function calling** support should be at least planned for chat type evolution.

---

## 9) Scope Assessment (v0.1.0)

Overall: **slightly ambitious but realistic** if constrained.

Realistic v0.1.0 if you keep:
- models.list
- chat.completions.create
- chat streaming
- basic retry + error mapping
- strong tests around parser/request/ownership

Potential scope cuts if schedule slips:
- Embeddings can move to v0.2
- Pagination definitely v0.2 unless needed
- Advanced error payload richness can be iterative

---

## 10) Recommendations for "Review Checklist Before Implementation"

From `zig-api.md:963-971`:

| Decision | Recommendation |
|---|---|
| Confirm Zig 0.16.x | ✅ Done (`zig version` shows `0.16.0`) |
| Re-check OpenRouter docs fields | Do this before freezing chat structs; current plan under-specifies modern fields |
| Re-check Go SDK resource names | Keep behavioral parity, but don't copy overload/option patterns |
| Decide `!T` vs `ApiResult(T)` | **Pick `!T` as sole public pattern** |
| Decide namespace storage layout | **Nested lightweight structs with `*Client`** |
| Decide mockable transport day one | **Yes, from day one** — minimal internal transport interface + fake transport in unit tests |

---

## Must-Fix Before Coding

1. Unify README and plan API shape.
2. Standardize deinit/allocator ownership contract globally (arena per response).
3. Choose single error model (`!T`).
4. Add compile-spike milestone to validate exact Zig 0.16 std APIs used in signatures.
5. Expand chat types (or add explicit "escape hatch" fields) to avoid immediate incompatibility.
