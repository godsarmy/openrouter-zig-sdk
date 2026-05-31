# Zig API Implementation Plan

This document tracks the plan for implementing an idiomatic Zig `0.16.x` OpenRouter API client while keeping naming and concepts familiar to the official OpenRouter Go SDK.

## Guiding Decision

Use the official Go SDK as a **behavioral and naming reference**, not as a direct implementation template.

Mirror:

- resource names
- operation names
- endpoint coverage
- request/response field names
- auth/header behavior
- streaming behavior
- retry and error behavior

Adapt for Zig:

- explicit allocators
- `snake_case` names
- options structs instead of Go variadic option functions
- `?T` for optional values
- `error{...}!T` for the primary public API
- iterator-style streaming
- compact handwritten internals instead of generated-code verbosity

## Review Decisions Incorporated

After reviewing the initial plan, use these choices as implementation constraints:

- [ ] Keep `client.chat.completions.create(...)` as the canonical chat API; update README/examples to match it before publishing.
- [ ] Public endpoint methods return `!T`, not `ApiResult(T)`. HTTP/API failures map to typed errors; rich `ApiError` payloads are internal/diagnostic unless a later API deliberately exposes them.
- [ ] Owning public response structs store their allocator/arena and expose `deinit(self)` only.
- [ ] Prefer an arena per parsed response/chunk to avoid nested string/slice free logic.
- [ ] Use lightweight embedded resource namespace structs; no heap allocation for namespaces.
- [ ] Make the HTTP transport mockable from day one so unit tests do not require network access.
- [x] Compile-check the exact Zig `0.16.x` `std.Io`, `std.http.Client`, and `std.json` APIs before freezing signatures.

## Target Public API Shape

Preferred style:

```zig
const std = @import("std");
const openrouter = @import("openrouter");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    var threaded: std.Io.Threaded = .init_single_threaded;
    defer threaded.deinit();

    var client = try openrouter.Client.init(allocator, threaded.io(), .{
        .api_key = std.posix.getenv("OPENROUTER_API_KEY") orelse return error.MissingApiKey,
        .http_referer = "https://example.com",
        .x_title = "openrouter-zig",
    });
    defer client.deinit();

    var response = try client.chat.completions.create(.{
        .model = "openai/gpt-4o-mini",
        .messages = &.{
            .{ .role = .user, .content = .{ .text = "Say hello from Zig." } },
        },
    }, .{});
    defer response.deinit();

    std.debug.print("{s}\n", .{response.choices[0].message.content.?});
}
```

Streaming style:

```zig
var stream = try client.chat.completions.stream(.{
    .model = "openai/gpt-4o-mini",
    .messages = &.{
        .{ .role = .user, .content = .{ .text = "Stream a short answer." } },
    },
}, .{});
defer stream.deinit();

while (try stream.next()) |chunk| {
    defer chunk.deinit();

    if (chunk.content()) |text| {
        std.debug.print("{s}", .{text});
    }
}
```

## Naming Policy

- [ ] Use OpenRouter/Go SDK resource concepts where possible.
- [ ] Use Zig naming style for symbols and fields.
- [ ] Prefer namespaced resources:
  - [ ] `client.chat.completions.create(...)`
  - [ ] `client.chat.completions.stream(...)`
  - [ ] `client.models.list(...)`
  - [ ] `client.embeddings.create(...)`
  - [ ] `client.credits.get(...)`
  - [ ] `client.providers.list(...)`
- [ ] Keep request JSON fields aligned with OpenRouter API field names.
- [ ] Avoid generated internal type names in public API.

## Non-Goals

- [ ] Do not directly port the generated Go SDK internals.
- [ ] Do not copy Go pointer-helper optional patterns.
- [ ] Do not expose Go-style variadic operation options.
- [ ] Do not use panic-style config validation.
- [ ] Do not implement the entire Go SDK surface in the first milestone.

---

# Milestone 0 — Repository Setup

## Files

- [x] `build.zig`
- [x] `build.zig.zon`
- [x] `src/openrouter.zig`
- [x] `src/client.zig`
- [x] `src/config.zig`
- [x] `src/options.zig`
- [x] `src/errors.zig`
- [x] `src/http.zig`
- [x] `src/json.zig`
- [x] `src/retry.zig`
- [x] `src/stream.zig`
- [x] `src/chat.zig`
- [x] `src/models.zig`
- [x] `src/embeddings.zig`
- [x] `examples/chat.zig`
- [x] `examples/stream.zig`
- [x] `examples/list_models.zig`

## Tasks

- [x] Create Zig package targeting Zig `0.16.x`.
- [x] Add library module named `openrouter`.
- [x] Add test step: `zig build test`.
- [x] Add example build steps.
- [x] Ensure `zig fmt .` works.

## Acceptance Criteria

- [x] `zig build` succeeds.
- [x] `zig build test` succeeds.
- [x] A consumer can `@import("openrouter")`.

---

# Milestone 0.5 — Zig 0.16 Compile Spike

## Goal

Verify the exact Zig `0.16.x` standard-library APIs before locking public signatures.

## Tasks

- [x] Confirm `std.Io` and `std.Io.Threaded` construction/usage compile on installed Zig `0.16.x`.
- [x] Confirm `std.http.Client` initialization with caller-provided I/O compiles.
- [x] Confirm `std.json` stringify/parse option names used by this plan compile.
- [x] Build a tiny throwaway request/response path using the planned `Client.init` shape.
- [x] Remove or fold the spike code into Milestone 1 once signatures are proven.

## Acceptance Criteria

- [x] Planned `Client.init(allocator, io, config)` signature is compile-verified.
- [x] Planned JSON helper options are compile-verified.
- [x] Any stdlib API differences are reflected back into this plan before implementation continues.

---

# Milestone 1 — Core Client and Configuration

## Goal

Implement the root client and shared configuration.

## Public Types

```zig
pub const Config = struct {
    api_key: []const u8,
    base_url: []const u8 = "https://openrouter.ai/api/v1",
    http_referer: ?[]const u8 = null,
    x_title: ?[]const u8 = null,
    timeout_ms: u64 = 60_000,
    retry: RetryConfig = .{},
};

pub const Client = struct {
    pub fn init(allocator: std.mem.Allocator, io: std.Io, config: Config) !Client;
    pub fn deinit(self: *Client) void;
};

// Resource namespace structs are lightweight embedded values.
// They are initialized by Client.init and do not allocate.
// Endpoint methods can recover the parent client with @fieldParentPtr as needed.
```

## Resource Namespaces

- [ ] `client.chat`
- [ ] `client.chat.completions`
- [ ] `client.models`
- [ ] `client.embeddings`
- [ ] Later: `client.credits`, `client.providers`, `client.guardrails`, `client.api_keys`, `client.workspaces`

## Tasks

- [x] Implement `Config`.
- [x] Implement `Client.init`.
- [x] Implement `Client.deinit`.
- [x] Store allocator explicitly.
- [x] Store caller-provided `std.Io` explicitly.
- [x] Initialize `std.http.Client` with `.allocator` and `.io`.
- [x] Do not create `std.Io.Threaded` inside library production code.
- [x] Initialize lightweight embedded resource namespace structs.
- [x] Validate base URL format without panicking.
- [x] Document that `Client` is not thread-safe unless externally synchronized or used as client-per-worker.

## Acceptance Criteria

- [x] Client initializes with API key.
- [x] Client initialization requires caller-provided `std.Io`.
- [x] Client supports custom base URL.
- [x] Client supports optional `HTTP-Referer`.
- [x] Client supports optional `X-Title`.
- [x] Client deinitializes cleanly.

---

# Milestone 2 — Request Options

## Goal

Replace Go-style operation options with Zig options structs.

## Public Types

```zig
pub const Header = struct {
    name: []const u8,
    value: []const u8,
};

pub const RequestOptions = struct {
    timeout_ms: ?u64 = null,
    retry: ?RetryConfig = null,
    extra_headers: []const Header = &.{},
};
```

## Tasks

- [x] Implement `Header`.
- [x] Implement `RequestOptions`.
- [x] Merge client defaults with per-request options.
- [x] Support extra headers.
- [x] Ensure user headers cannot accidentally remove required auth unless explicitly designed later.

## Acceptance Criteria

- [x] Per-request timeout override is accepted.
- [x] Per-request retry override is accepted.
- [x] Extra headers are included in merged request options.
- [x] Reserved built-in headers are rejected in `extra_headers`.

---

# Milestone 3 — HTTP Layer

## Goal

Centralize all HTTP behavior instead of duplicating endpoint logic.

## HTTP Library Decision

- [ ] Use Zig standard library HTTP support as the default transport.
- [ ] Primary planned transport: `std.http.Client` initialized with caller-provided `std.Io`.
- [ ] App code owns the I/O backend, usually `std.Io.Threaded`.
- [ ] Library code must accept/store `std.Io`; it must not secretly create a global/default I/O backend.
- [ ] Avoid adding a third-party HTTP dependency for `v0.1.0` unless `std.http.Client` proves insufficient for Zig `0.16.x` streaming or TLS behavior.
- [ ] Keep the HTTP layer isolated so an alternate transport can be added later without changing endpoint APIs.
- [ ] Define a small internal transport interface/fake transport from day one for unit tests.

## Sync/Async Decision for Zig 0.16

The primary public API should be synchronous/blocking at the call site:

```zig
var response = try client.chat.completions.create(request, .{});
defer response.deinit();
```

Streaming should use a pull iterator:

```zig
var stream = try client.chat.completions.stream(request, .{});
defer stream.deinit();

while (try stream.next()) |chunk| {
    defer chunk.deinit();
}
```

Rationale:

- Zig `0.16.x` makes I/O an explicit interface. `std.http.Client` should be constructed with a caller-provided `std.Io`.
- The safest library endpoint API remains a simple request/response surface.
- App authors choose the I/O backend and can run requests with `std.Io.Threaded`, `io.async`, `io.concurrent`, worker threads, or a future alternate backend.
- The library should not force a specific event loop or async runtime.
- True async/event-loop support can be added later through an alternate transport layer or optional wrapper API.

Application setup example:

```zig
var threaded: std.Io.Threaded = .init_single_threaded;
defer threaded.deinit();

var client = try openrouter.Client.init(allocator, threaded.io(), .{
    .api_key = api_key,
});
defer client.deinit();
```

Concurrent app usage should be implemented by the application around the sync call. If the app uses `io.async` or `io.concurrent`, it owns cancellation and lifetime of request memory.

Future async/concurrency compatibility requirements:

- [ ] Require caller-provided `std.Io` in `Client.init`.
- [ ] Do not expose transport internals in endpoint APIs.
- [ ] Keep request/response types independent of `std.http.Client`.
- [ ] Return stream objects with explicit `deinit` so callers can cancel/close early.
- [ ] Surface cancellation/closed-stream errors clearly where supported.
- [ ] Propagate `error.Canceled` where the underlying I/O reports cancellation.
- [ ] Use `std.testing.io` for I/O-oriented tests where possible.
- [ ] Document `-fsingle-threaded` vs `-fno-single-threaded` behavior where relevant.
- [ ] Prefer client-per-worker or externally synchronized usage until thread-safety is verified.
- [ ] Add optional async/task wrappers only after the sync API is stable.

## Internal Types

```zig
pub const HttpRequest = struct {
    method: std.http.Method,
    path: []const u8,
    query: ?[]const u8 = null,
    body: ?[]const u8 = null,
    accept: []const u8 = "application/json",
    content_type: ?[]const u8 = "application/json",
};

pub const HttpResponse = struct {
    allocator: std.mem.Allocator,
    status: std.http.Status,
    body: []u8,
    content_type: ?[]const u8 = null,
    request_id: ?[]const u8 = null,
    rate_limit_remaining: ?[]const u8 = null,
    rate_limit_reset: ?[]const u8 = null,

    pub fn deinit(self: *HttpResponse) void;
};
```

## Required Headers

- [ ] `Authorization: Bearer <api-key>`
- [ ] `User-Agent: openrouter-zig/<version>`
- [ ] `Accept: application/json` by default
- [ ] `Content-Type: application/json` when body exists
- [ ] Optional `HTTP-Referer`
- [ ] Optional `X-Title`

## Tasks

- [ ] Build full URL from `base_url`, path, and query.
- [ ] Implement auth header creation.
- [ ] Implement default headers.
- [ ] Implement optional OpenRouter attribution headers.
- [ ] Implement request body sending.
- [ ] Implement response body allocation.
- [ ] Preserve response status.
- [ ] Capture response content type.
- [ ] Capture useful response metadata when present, such as request id and rate-limit headers.
- [ ] Redact authorization header from debug/error messages.
- [ ] Add fake/mock transport support for tests.

## Acceptance Criteria

- [ ] HTTP layer can issue `GET`.
- [ ] HTTP layer can issue `POST` with JSON body.
- [ ] Response body ownership is documented.
- [ ] HTTP layer can be unit tested without network.
- [ ] No API key appears in errors/logs.

---

# Milestone 4 — JSON Helpers

## Goal

Centralize JSON encoding/decoding behavior.

## Tasks

- [ ] Add request stringify helper.
- [ ] Add response parse helper.
- [ ] Use `.emit_null_optional_fields = false` for request JSON where appropriate.
- [ ] Use `.ignore_unknown_fields = true` for response JSON.
- [ ] Add helpers for string enums if needed.

## Acceptance Criteria

- [ ] Optional null request fields are not emitted by default.
- [ ] Unknown response fields do not break parsing.
- [ ] Invalid JSON returns a clear parse error.

---

# Milestone 5 — Error Handling

## Goal

Map OpenRouter HTTP/API errors into useful Zig errors and payloads.

## Known Statuses to Handle

- [ ] `400 BadRequest`
- [ ] `401 Unauthorized`
- [ ] `402 PaymentRequired`
- [ ] `404 NotFound`
- [ ] `408 RequestTimeout`
- [ ] `413 PayloadTooLarge`
- [ ] `422 UnprocessableEntity`
- [ ] `429 RateLimited`
- [ ] `500 InternalServerError`
- [ ] `502 BadGateway`
- [ ] `503 ServiceUnavailable`
- [ ] `524 Timeout`
- [ ] `529 Overloaded`

## Proposed Types

```zig
pub const ApiError = struct {
    arena: std.heap.ArenaAllocator,
    status: u16,
    code: ?[]const u8 = null,
    message: []const u8,
    raw_body: []const u8,
    request_id: ?[]const u8 = null,

    pub fn deinit(self: *ApiError) void;
};
```

Public endpoint methods should return `!T`. Do not expose a second `ApiResult(T)` success/error style in the v0.1 public API. Keep rich `ApiError` payload handling centralized in the HTTP/error layer so a future explicit diagnostic API can expose it without changing endpoint method names.

## Tasks

- [ ] Implement status-code mapping.
- [ ] Parse OpenRouter error JSON when possible.
- [ ] Preserve raw body for unknown error shapes.
- [ ] Implement generic fallback API error.
- [ ] Ensure all owned error fields can be freed.
- [ ] Keep public endpoint return style consistently `!T`.

## Acceptance Criteria

- [ ] `401` maps to unauthorized error behavior.
- [ ] `429` maps to rate-limited behavior.
- [ ] `5xx` errors are detectable for retry.
- [ ] Unknown `4xx/5xx` builds a generic `ApiError` payload and returns `error.ApiError`.
- [ ] Public methods do not mix `!T` and `ApiResult(T)` styles.

---

# Milestone 6 — Retry

## Goal

Implement central retry behavior similar to the Go SDK, but simpler.

## Public Type

```zig
pub const RetryConfig = struct {
    max_attempts: u8 = 3,
    initial_delay_ms: u64 = 500,
    max_delay_ms: u64 = 60_000,
    multiplier: f64 = 1.5,
    retry_connection_errors: bool = true,
    retry_5xx: bool = true,
    retry_429: bool = true,
};
```

## Retryable Conditions

- [ ] Connection errors, if enabled
- [ ] `500`
- [ ] `502`
- [ ] `503`
- [ ] `524`
- [ ] `529`
- [ ] `429`, if enabled

## Tasks

- [ ] Implement retry decision function.
- [ ] Implement exponential backoff.
- [ ] Respect `Retry-After` header when available.
- [ ] Bound max attempts.
- [ ] Bound max delay.
- [ ] Allow per-request retry override.

## Acceptance Criteria

- [ ] Retry policy is tested independently.
- [ ] Non-retryable `4xx` statuses are not retried.
- [ ] Retry stops at configured max attempts.

---

# Milestone 7 — Models API

## Goal

Implement the simplest useful endpoint first.

## Endpoint

```text
GET /models
```

## Public API

```zig
var result = try client.models.list(.{});
defer result.deinit();
```

## Proposed Types

```zig
pub const ListResponse = struct {
    arena: std.heap.ArenaAllocator,
    data: []Model,

    pub fn deinit(self: *ListResponse) void;
};

pub const Model = struct {
    id: []const u8,
    name: ?[]const u8 = null,
    description: ?[]const u8 = null,
    context_length: ?u32 = null,
    pricing: ?Pricing = null,
};

pub const Pricing = struct {
    prompt: ?[]const u8 = null,
    completion: ?[]const u8 = null,
    image: ?[]const u8 = null,
    request: ?[]const u8 = null,
};
```

## Tasks

- [ ] Implement `client.models.list(options)`.
- [ ] Parse model list response.
- [ ] Add model response deinit logic.
- [ ] Add example `examples/list_models.zig`.

## Acceptance Criteria

- [ ] `client.models.list(.{})` compiles.
- [ ] Model IDs are accessible.
- [ ] Unknown fields in model JSON are ignored.

---

# Milestone 8 — Chat Completions API

## Goal

Implement non-streaming chat completions.

## Endpoint

```text
POST /chat/completions
```

## Public API

```zig
var response = try client.chat.completions.create(.{
    .model = "openai/gpt-4o-mini",
    .messages = &.{
        .{ .role = .user, .content = .{ .text = "Hello from Zig." } },
    },
}, .{});
defer response.deinit();
```

## Proposed Types

```zig
pub const Role = enum {
    system,
    user,
    assistant,
    tool,
};

pub const Message = struct {
    role: Role,
    content: MessageContent,
    name: ?[]const u8 = null,
    tool_call_id: ?[]const u8 = null,
    tool_calls: ?[]const ToolCall = null,
};

pub const MessageContent = union(enum) {
    text: []const u8,
    parts: []const ContentPart,
};

pub const ContentPart = union(enum) {
    text: []const u8,
    image_url: []const u8,
};

pub const ToolCall = struct {
    id: []const u8,
    name: []const u8,
    arguments: []const u8,
};

pub const CompletionRequest = struct {
    model: []const u8,
    messages: []const Message,
    temperature: ?f32 = null,
    top_p: ?f32 = null,
    max_tokens: ?u32 = null,
    seed: ?i64 = null,
    frequency_penalty: ?f32 = null,
    presence_penalty: ?f32 = null,
    response_format: ?ResponseFormat = null,
    provider: ?ProviderRouting = null,
    stream: bool = false,
    stop: ?[]const []const u8 = null,
    // Escape hatch for OpenRouter/provider fields not typed yet.
    // Exact representation should be compile-checked in JSON helpers.
    extra_body: ?std.json.Value = null,
};

pub const ResponseFormat = struct {
    type: []const u8,
};

pub const ProviderRouting = struct {
    order: ?[]const []const u8 = null,
    allow_fallbacks: ?bool = null,
    require_parameters: ?bool = null,
};

pub const CompletionResponse = struct {
    arena: std.heap.ArenaAllocator,
    id: []const u8,
    model: []const u8,
    choices: []Choice,
    usage: ?Usage = null,

    pub fn deinit(self: *CompletionResponse) void;
};

pub const Choice = struct {
    index: u32,
    message: AssistantMessage,
    finish_reason: ?[]const u8 = null,
};

pub const AssistantMessage = struct {
    role: Role,
    content: ?[]const u8 = null,
};

pub const Usage = struct {
    prompt_tokens: ?u32 = null,
    completion_tokens: ?u32 = null,
    total_tokens: ?u32 = null,
};
```

## Tasks

- [ ] Implement `client.chat.completions.create(request, options)`.
- [ ] Serialize chat request.
- [ ] Ensure `.stream = false` for non-streaming path.
- [ ] Re-check OpenRouter docs before freezing the final typed chat fields.
- [ ] Preserve an escape hatch for unsupported provider/OpenRouter request fields.
- [ ] Parse chat response.
- [ ] Add deinit logic for owned response data.
- [ ] Add example `examples/chat.zig`.

## Acceptance Criteria

- [ ] Chat request JSON matches OpenRouter field names.
- [ ] Optional fields are omitted when null.
- [ ] Non-streaming response parses successfully.
- [ ] Usage data is parsed when present.

---

# Milestone 9 — Chat Streaming API

## Goal

Implement `text/event-stream` chat completions.

## Public API

```zig
var stream = try client.chat.completions.stream(.{
    .model = "openai/gpt-4o-mini",
    .messages = &.{
        .{ .role = .user, .content = .{ .text = "Stream a short answer." } },
    },
}, .{});
defer stream.deinit();

while (try stream.next()) |chunk| {
    defer chunk.deinit();

    if (chunk.content()) |text| {
        std.debug.print("{s}", .{text});
    }
}
```

## Proposed Types

```zig
pub const CompletionStream = struct {
    pub fn next(self: *CompletionStream) !?CompletionChunk;
    pub fn deinit(self: *CompletionStream) void;
};

pub const CompletionChunk = struct {
    arena: std.heap.ArenaAllocator,
    id: ?[]const u8 = null,
    model: ?[]const u8 = null,
    choices: []ChunkChoice,

    pub fn content(self: CompletionChunk) ?[]const u8;
    pub fn deinit(self: *CompletionChunk) void;
};

pub const ChunkChoice = struct {
    index: u32,
    delta: Delta,
    finish_reason: ?[]const u8 = null,
};

pub const Delta = struct {
    role: ?Role = null,
    content: ?[]const u8 = null,
};
```

## SSE Behavior

- [ ] Parse event boundaries separated by blank lines.
- [ ] Parse `data:` lines, including multiple `data:` lines per event joined with `\n`.
- [ ] Ignore comment/keepalive lines beginning with `:`.
- [ ] Ignore unsupported `event:`, `id:`, and `retry:` fields unless needed later.
- [ ] Handle LF and CRLF line endings.
- [ ] Enforce bounded line/event sizes to avoid unbounded memory growth.
- [ ] Stop on `data: [DONE]`.
- [ ] Return malformed JSON errors clearly.
- [ ] Distinguish malformed SSE, malformed JSON, unexpected upstream close, and cancellation where possible.
- [ ] Close response body on `deinit`.
- [ ] After done, repeated `next()` calls return `null`.

## Tasks

- [ ] Implement SSE parser in `stream.zig`.
- [ ] Implement chat stream request.
- [ ] Set request body `.stream = true`.
- [ ] Use `Accept: text/event-stream`.
- [ ] Parse each chunk as JSON.
- [ ] Add example `examples/stream.zig`.

## Acceptance Criteria

- [ ] Stream iterator returns chunks.
- [ ] Stream stops on `[DONE]`.
- [ ] Stream deinitializes cleanly if user exits early.
- [ ] SSE parser is unit tested without network.

---

# Milestone 10 — Embeddings API

## Goal

Implement embeddings after core request/response patterns stabilize.

## Endpoint

```text
POST /embeddings
```

## Public API

```zig
var response = try client.embeddings.create(.{
    .model = "openai/text-embedding-3-small",
    .input = .{ .string = "Hello from Zig." },
}, .{});
defer response.deinit();
```

## Proposed Types

```zig
pub const CreateRequest = struct {
    model: []const u8,
    input: Input,
};

pub const Input = union(enum) {
    string: []const u8,
    strings: []const []const u8,
};

pub const CreateResponse = struct {
    arena: std.heap.ArenaAllocator,
    data: []Embedding,
    model: []const u8,
    usage: ?chat.Usage = null,

    pub fn deinit(self: *CreateResponse) void;
};

pub const Embedding = struct {
    index: u32,
    embedding: []f32,
};
```

## Tasks

- [ ] Implement embeddings request serialization.
- [ ] Implement embeddings response parsing.
- [ ] Add deinit logic.
- [ ] Add tests for string and string-array inputs.

## Acceptance Criteria

- [ ] Single input string works.
- [ ] Multiple input strings work.
- [ ] Embedding vectors are accessible.

---

# Milestone 11 — Pagination Pattern

## Goal

Add pagination support for endpoints that need it without copying Go closure-based pagination.

## Proposed Pattern

```zig
pub fn Pager(comptime Page: type) type {
    return struct {
        pub fn next(self: *@This()) !?Page;
    };
}
```

## Tasks

- [ ] Identify paginated OpenRouter endpoints.
- [ ] Support offset/limit pagination.
- [ ] Use pager structs, not closures attached to responses.
- [ ] Keep pagination optional for initial endpoints.

## Acceptance Criteria

- [ ] Pager returns `null` when complete.
- [ ] Pager deinitializes any owned state.
- [ ] Pagination behavior is unit tested with mocked pages.

---

# Milestone 12 — Additional Resources

Implement after `v0.1.0` core is stable.

## Candidate Resources

- [ ] `client.credits.get(...)`
- [ ] `client.providers.list(...)`
- [ ] `client.endpoints.list(...)`
- [ ] `client.guardrails.*`
- [ ] `client.api_keys.*`
- [ ] `client.workspaces.*`
- [ ] `client.responses.*` beta API
- [ ] `client.rerank.create(...)`
- [ ] `client.tts.create(...)`
- [ ] `client.video_generation.*`
- [ ] OAuth helpers

## Acceptance Criteria

- [ ] Each new resource follows established naming style.
- [ ] Each new resource has tests.
- [ ] Each new resource has clear ownership/deinit behavior.

---

# Milestone 13 — Tests

## Unit Tests

- [ ] Config validation.
- [ ] Fake/mock HTTP transport behavior.
- [ ] URL construction.
- [ ] Auth header construction.
- [ ] Optional headers.
- [x] Extra request headers.
- [ ] JSON request encoding.
- [ ] JSON response parsing.
- [ ] Unknown response fields.
- [ ] Error status mapping.
- [ ] Retry decision logic.
- [ ] Retry backoff calculation.
- [ ] SSE parsing.
- [ ] `[DONE]` stream termination.
- [ ] Response `deinit` behavior.
- [ ] Arena-backed response cleanup behavior.

## Integration Tests

Integration tests must be opt-in and require environment variables.

- [ ] `OPENROUTER_API_KEY`
- [ ] Optional `OPENROUTER_HTTP_REFERER`
- [ ] Optional `OPENROUTER_APP_TITLE`

## Acceptance Criteria

- [ ] `zig build test` does not require network.
- [ ] `zig build integration-test` may require credentials.
- [ ] Tests do not print API keys.

---

# Milestone 14 — Examples and Documentation

## Examples

- [ ] `examples/list_models.zig`
- [ ] `examples/chat.zig`
- [ ] `examples/stream.zig`
- [ ] Later: `examples/embeddings.zig`

## Documentation

- [ ] Update `README.md` to use the canonical `client.chat.completions.create(...)` API before publishing examples.
- [ ] Document allocator ownership.
- [ ] Document response deinit requirements.
- [ ] Document streaming lifecycle.
- [ ] Document `Client` thread-safety policy.
- [ ] Document retry behavior.
- [ ] Document error behavior.
- [ ] Document supported endpoints.

## Acceptance Criteria

- [ ] Examples compile.
- [ ] README examples match actual API.
- [ ] Public API docs do not describe unimplemented features as complete.

---

# v0.1.0 Scope

## Required

- [ ] Zig package builds on Zig `0.16.x`.
- [ ] `Client.init` / `Client.deinit`.
- [ ] Config with API key, base URL, timeout, referer, title.
- [ ] Caller-provided `std.Io` support.
- [ ] Request options.
- [ ] Central HTTP layer.
- [ ] JSON helpers.
- [ ] Error handling.
- [ ] Basic retry.
- [ ] `client.models.list`.
- [ ] `client.chat.completions.create`.
- [ ] `client.chat.completions.stream`.
- [ ] Unit tests.
- [ ] Examples.

## Deferred

- [ ] Full management API coverage.
- [ ] OAuth.
- [ ] Video generation.
- [ ] Guardrails.
- [ ] Workspaces.
- [ ] Advanced provider routing helpers.
- [ ] Generated API compatibility layer.

---

# Compatibility Strategy

## Primary API

Handwritten, Zig-idiomatic, semver-stable.

## Optional Future Compatibility Layer

If exact Go SDK/OpenAPI parity becomes important, add an experimental namespace later:

```zig
openrouter.experimental.generated
```

Rules:

- [ ] Keep generated/compat types out of the main API.
- [ ] Mark experimental APIs clearly.
- [ ] Do not let generated naming destabilize the stable API.

---

# Review Checklist Before Implementation

- [x] Confirm installed Zig version is `0.16.x` (`0.16.0` installed).
- [ ] Re-check OpenRouter docs for current endpoint fields.
- [ ] Re-check official Go SDK for current resource names.
- [x] Public endpoint methods return `!T`; do not expose `ApiResult(T)` in v0.1.
- [x] Resource namespaces are lightweight embedded structs initialized by `Client.init`.
- [x] HTTP transport is mockable from day one with an internal fake transport for tests.

---

# Current Repository Status

- [x] `README.md` exists.
- [x] `AGENT.md` exists.
- [x] `.gitignore` exists.
- [x] Zig package files exist.
- [ ] Library implementation exists.
- [x] Tests exist.
- [x] Examples exist.
