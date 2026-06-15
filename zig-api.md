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

- [x] Keep `client.chat.completions.create(...)` as the canonical chat API; update README/examples to match it before publishing.
- [x] Public endpoint methods return `!T`, not `ApiResult(T)`. HTTP/API failures map to typed errors; rich `ApiError` payloads are internal/diagnostic unless a later API deliberately exposes them.
- [x] Owning public response structs store their allocator/arena and expose `deinit(self)` only.
- [x] Prefer an arena per parsed response/chunk to avoid nested string/slice free logic.
- [x] Use lightweight embedded resource namespace structs; no heap allocation for namespaces.
- [x] Make the HTTP transport mockable from day one so unit tests do not require network access.
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

- [x] Use OpenRouter/Go SDK resource concepts where possible.
- [x] Use Zig naming style for symbols and fields.
- [x] Prefer namespaced resources:
  - [x] `client.chat.completions.create(...)`
  - [x] `client.chat.completions.stream(...)`
  - [x] `client.models.list(...)`
  - [x] `client.embeddings.create(...)`
  - [x] `client.credits.get(...)`
  - [x] `client.providers.list(...)`
  - [x] `client.messages.create(...)` / `client.messages.stream(...)`
  - [x] `client.responses.create(...)`
  - [x] `client.presets.chat.completions.create(...)`
  - [x] `client.presets.messages.create(...)`
  - [x] `client.presets.responses.create(...)`
  - [x] management namespaces such as `client.keys`, `client.byok`, `client.guardrails`, `client.workspaces`, and `client.observability`
- [x] Keep request JSON fields aligned with OpenRouter API field names.
- [x] Avoid generated internal type names in public API.

## Non-Goals

- [x] Do not directly port the generated Go SDK internals.
- [x] Do not copy Go pointer-helper optional patterns.
- [x] Do not expose Go-style variadic operation options.
- [x] Do not use panic-style config validation.
- [x] Do not implement the entire Go SDK surface in the first milestone.

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
- [x] `src/pagination.zig`
- [x] `src/stream.zig`
- [x] `src/chat.zig`
- [x] `src/models.zig`
- [x] `src/embeddings.zig`
- [x] `src/credits.zig`
- [x] `src/providers.zig`
- [x] `examples/chat.zig`
- [x] `examples/stream.zig`
- [x] `examples/list_models.zig`
- [x] `examples/embeddings.zig`
- [x] `examples/credits.zig`
- [x] `examples/providers.zig`

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

- [x] `client.chat`
- [x] `client.chat.completions`
- [x] `client.models`
- [x] `client.embeddings`
- [x] `client.guardrails`
- [x] `client.keys`
- [x] `client.byok`
- [x] `client.workspaces`
- [x] `client.observability`
- [x] `client.organization`

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

- [x] Use Zig standard library HTTP support as the default transport.
- [x] Primary planned transport: `std.http.Client` initialized with caller-provided `std.Io`.
- [x] App code owns the I/O backend, usually `std.Io.Threaded`.
- [x] Library code must accept/store `std.Io`; it must not secretly create a global/default I/O backend.
- [x] Avoid adding a third-party HTTP dependency for `v0.1.0` unless `std.http.Client` proves insufficient for Zig `0.16.x` streaming or TLS behavior.
- [x] Keep the HTTP layer isolated so an alternate transport can be added later without changing endpoint APIs.
- [x] Define a small internal transport interface/fake transport from day one for unit tests.

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

Async/concurrency compatibility requirements:

- [x] Require caller-provided `std.Io` in `Client.init`.
- [x] Do not expose transport internals in endpoint APIs.
- [x] Keep request/response types independent of `std.http.Client`.
- [x] Return stream objects with explicit `deinit` so callers can cancel/close early.
- [x] Surface closed-stream errors clearly where supported.
- [x] Propagate `error.Canceled` where the underlying I/O reports cancellation.
- [x] Document `-fsingle-threaded` vs `-fno-single-threaded` behavior where relevant.
- [x] Prefer client-per-worker or externally synchronized usage until thread-safety is verified.
- [x] Add optional async/task wrappers only after the sync API is stable.

- [x] Use `std.testing.io` for client initialization unit tests where no real network I/O is required.

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
    generation_id: ?[]const u8 = null,
    request_id: ?[]const u8 = null,
    rate_limit_remaining: ?[]const u8 = null,
    rate_limit_reset: ?[]const u8 = null,

    pub fn deinit(self: *HttpResponse) void;
};

pub const ResponseMetadata = struct {
    content_type: ?[]const u8 = null,
    generation_id: ?[]const u8 = null,
    request_id: ?[]const u8 = null,
    rate_limit_remaining: ?[]const u8 = null,
    rate_limit_reset: ?[]const u8 = null,

    pub fn fromHttpResponse(allocator: std.mem.Allocator, response: HttpResponse) !ResponseMetadata;
    pub fn deinit(self: *ResponseMetadata, allocator: std.mem.Allocator) void;
};
```

## Required Headers

- [x] `Authorization: Bearer <api-key>`
- [x] `User-Agent: openrouter-zig/<version>`
- [x] `Accept: application/json` by default
- [x] `Content-Type: application/json` when body exists
- [x] Optional `HTTP-Referer`
- [x] Optional `X-Title`

## Tasks

- [x] Build full URL from `base_url`, path, and query.
- [x] Implement auth header creation.
- [x] Implement default headers.
- [x] Implement optional OpenRouter attribution headers.
- [x] Implement request body sending.
- [x] Implement response body allocation.
- [x] Preserve response status.
- [x] Capture response content type.
- [x] Capture useful response metadata when present, such as request id and rate-limit headers.
- [x] Expose captured response metadata on core inference response structs.
- [x] Redact authorization header from debug/error messages.
- [x] Add fake/mock transport support for tests.

## Acceptance Criteria

- [x] HTTP layer can issue `GET`.
- [x] HTTP layer can issue `POST` with JSON body.
- [x] Response body ownership is documented.
- [x] HTTP layer can be unit tested without network.
- [x] No API key appears in errors/logs.

---

# Milestone 4 — JSON Helpers

## Goal

Centralize JSON encoding/decoding behavior.

## Tasks

- [x] Add request stringify helper.
- [x] Add response parse helper.
- [x] Use `.emit_null_optional_fields = false` for request JSON where appropriate.
- [x] Use `.ignore_unknown_fields = true` for response JSON.
- [x] Add helpers for string enums if needed.

## Acceptance Criteria

- [x] Optional null request fields are not emitted by default.
- [x] Unknown response fields do not break parsing.
- [x] Invalid JSON returns a clear parse error.

---

# Milestone 5 — Error Handling

## Goal

Map OpenRouter HTTP/API errors into useful Zig errors and payloads.

## Known Statuses to Handle

- [x] `400 BadRequest`
- [x] `401 Unauthorized`
- [x] `402 PaymentRequired`
- [x] `404 NotFound`
- [x] `408 RequestTimeout`
- [x] `413 PayloadTooLarge`
- [x] `422 UnprocessableEntity`
- [x] `429 RateLimited`
- [x] `500 InternalServerError`
- [x] `502 BadGateway`
- [x] `503 ServiceUnavailable`
- [x] `524 Timeout`
- [x] `529 Overloaded`

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

- [x] Implement status-code mapping.
- [x] Parse OpenRouter error JSON when possible.
- [x] Preserve raw body for unknown error shapes.
- [x] Implement generic fallback API error.
- [x] Ensure all owned error fields can be freed.
- [x] Keep public endpoint return style consistently `!T`.

## Acceptance Criteria

- [x] `401` maps to unauthorized error behavior.
- [x] `429` maps to rate-limited behavior.
- [x] `5xx` errors are detectable for retry.
- [x] Unknown `4xx/5xx` builds a generic `ApiError` payload and returns `error.ApiError`.
- [x] Public methods do not mix `!T` and `ApiResult(T)` styles.

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

- [x] Connection errors, if enabled
- [x] `500`
- [x] `502`
- [x] `503`
- [x] `524`
- [x] `529`
- [x] `429`, if enabled

## Tasks

- [x] Implement retry decision function.
- [x] Implement exponential backoff.
- [x] Respect `Retry-After` header when available.
- [x] Bound max attempts.
- [x] Bound max delay.
- [x] Allow per-request retry override.

## Acceptance Criteria

- [x] Retry policy is tested independently.
- [x] Non-retryable `4xx` statuses are not retried.
- [x] Retry stops at configured max attempts.

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
    web_search: ?[]const u8 = null,
    internal_reasoning: ?[]const u8 = null,
    input_cache_read: ?[]const u8 = null,
    input_cache_write: ?[]const u8 = null,
    audio: ?[]const u8 = null,
    audio_output: ?[]const u8 = null,
    image_output: ?[]const u8 = null,
    image_token: ?[]const u8 = null,
    input_audio_cache: ?[]const u8 = null,
    discount: ?f64 = null,
};
```

## Tasks

- [x] Implement `client.models.list(options)`.
- [x] Parse model list response.
- [x] Add model response deinit logic.
- [x] Add example `examples/list_models.zig`.

## Acceptance Criteria

- [x] `client.models.list(.{})` compiles.
- [x] Model IDs are accessible.
- [x] Unknown fields in model JSON are ignored.

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
    response_metadata: http.ResponseMetadata = .{},
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

- [x] Implement `client.chat.completions.create(request, options)`.
- [x] Serialize chat request.
- [x] Ensure `.stream = false` for non-streaming path.
- [x] Re-check OpenRouter docs before freezing the final typed chat fields.
- [x] Preserve an escape hatch for unsupported provider/OpenRouter request fields.
- [x] Parse chat response.
- [x] Expose response metadata on parsed chat responses.
- [x] Add deinit logic for owned response data.
- [x] Add example `examples/chat.zig`.

## Acceptance Criteria

- [x] Chat request JSON matches OpenRouter field names.
- [x] Optional fields are omitted when null.
- [x] Non-streaming response parses successfully.
- [x] Usage data is parsed when present.

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

- [x] Parse event boundaries separated by blank lines.
- [x] Parse `data:` lines, including multiple `data:` lines per event joined with `\n`.
- [x] Ignore comment/keepalive lines beginning with `:`.
- [x] Ignore unsupported `event:`, `id:`, and `retry:` fields unless needed later.
- [x] Handle LF and CRLF line endings.
- [x] Enforce bounded line/event sizes to avoid unbounded memory growth.
- [x] Stop on `data: [DONE]`.
- [x] Return malformed JSON errors clearly.
- [x] Distinguish malformed SSE, malformed JSON, and unexpected upstream close where possible.
- [x] Close response body on `deinit`.
- [x] After done, repeated `next()` calls return `null`.

## Tasks

- [x] Implement SSE parser in `stream.zig`.
- [x] Implement chat stream request.
- [x] Set request body `.stream = true`.
- [x] Use `Accept: text/event-stream`.
- [x] Parse each chunk as JSON.
- [x] Add example `examples/stream.zig`.

## Acceptance Criteria

- [x] Stream iterator returns chunks.
- [x] Stream stops on `[DONE]`.
- [x] Stream deinitializes cleanly if user exits early.
- [x] SSE parser is unit tested without network.

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
    response_metadata: http.ResponseMetadata = .{},
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

- [x] Implement embeddings request serialization.
- [x] Implement embeddings response parsing.
- [x] Expose response metadata on parsed embeddings responses.
- [x] Add deinit logic.
- [x] Add tests for string and string-array inputs.

## Acceptance Criteria

- [x] Single input string works.
- [x] Multiple input strings work.
- [x] Embedding vectors are accessible.

---

# Milestone 11 — Pagination Pattern

## Goal

Add pagination support for endpoints that need it without copying Go closure-based pagination.

Known offset/limit paginated endpoint families from the OpenRouter Go SDK/OpenAPI include workspaces, guardrails and assignment lists, API key lists, and organization member lists. Core `models`, `chat`, and `embeddings` endpoints do not currently need pagers.

## Proposed Pattern

```zig
pub fn Pager(comptime Page: type) type {
    return struct {
        pub fn next(self: *@This()) !?Page;
    };
}
```

## Tasks

- [x] Identify paginated OpenRouter endpoints.
- [x] Support offset/limit pagination.
- [x] Use pager structs, not closures attached to responses.
- [x] Keep pagination optional for initial endpoints.

## Acceptance Criteria

- [x] Pager returns `null` when complete.
- [x] Pager deinitializes any owned state.
- [x] Pagination behavior is unit tested with mocked pages.

---

# Milestone 12 — Additional Resources

Implement after `v0.1.0` core is stable.

## Candidate Resources

- [x] `client.credits.get(...)`
- [x] `client.providers.list(...)`
- [x] `client.endpoints.zdr.list(...)`
- [x] `client.guardrails.*`
- [x] `client.keys.*`
- [x] `client.byok.*`
- [x] `client.workspaces.*`
- [x] `client.observability.*`
- [x] `client.organization.members.*`
- [x] `client.responses.*` beta API
- [x] `client.messages.*`
- [x] `client.presets.*`
- [x] `client.rerank.create(...)`
- [x] `client.audio.speech.create(...)`
- [x] `client.audio.transcriptions.create(...)`
- [x] `client.videos.*`

Future resource candidates:

- OAuth helpers.

## Acceptance Criteria

- [x] Each implemented resource follows established naming style.
- [x] Each implemented resource has tests.
- [x] Each implemented resource has clear ownership/deinit behavior.

---

# Milestone 13 — Tests

## Unit Tests

- [x] Config validation.
- [x] Fake/mock HTTP transport behavior.
- [x] URL construction.
- [x] Auth header construction.
- [x] Optional headers.
- [x] Extra request headers.
- [x] JSON request encoding.
- [x] JSON response parsing.
- [x] Unknown response fields.
- [x] Error status mapping.
- [x] Retry decision logic.
- [x] Retry backoff calculation.
- [x] SSE parsing.
- [x] `[DONE]` stream termination.
- [x] Response `deinit` behavior.
- [x] Arena-backed response cleanup behavior.
- [x] Response metadata capture and ownership behavior.

## Integration Tests

Integration tests must be opt-in and require environment variables.

- [x] `OPENROUTER_API_KEY`
- [x] Optional `OPENROUTER_HTTP_REFERER`
- [x] Optional `OPENROUTER_APP_TITLE`

## Acceptance Criteria

- [x] `zig build test` does not require network.
- [x] `zig build integration-test` may require credentials.
- [x] Tests do not print API keys.

---

# Milestone 14 — Examples and Documentation

## Examples

- [x] `examples/list_models.zig`
- [x] `examples/chat.zig`
- [x] `examples/stream.zig`
- [x] `examples/embeddings.zig`
- [x] `examples/credits.zig`
- [x] `examples/providers.zig`
- [x] endpoint-specific examples for audio, messages, responses, rerank, video, presets, management APIs, generation, activity, and rankings daily.

## Documentation

- [x] Update `README.md` to use the canonical `client.chat.completions.create(...)` API before publishing examples.
- [x] Keep `README.md` concise and move detailed endpoint, ownership, and contributor guidance into `APIs.md`, `zig-api.md`, and `AGENT.md`.
- [x] Document allocator ownership.
- [x] Document response deinit requirements.
- [x] Document streaming lifecycle.
- [x] Document `Client` thread-safety policy.
- [x] Document retry behavior.
- [x] Document error behavior.
- [x] Document supported endpoints.
- [x] Document response metadata ownership.

## Ownership Reference

The public README intentionally keeps ownership guidance brief. Detailed expectations:

- The caller provides the allocator and `std.Io` to `Client.init`.
- Normal applications should provide an application-owned `std.Io.Threaded` or another real I/O backend; unit tests that only need a client can use `std.testing.io`.
- The SDK should not assume `-fsingle-threaded` behavior. Callers choose the I/O backend and concurrency model, and integration tests that perform network I/O should keep explicit `std.Io.Threaded` setup.
- The client owns its internal HTTP client and must be closed with `client.deinit()`.
- Parsed response values, raw/binary response values, stream chunks, and stream events own their returned data and expose `deinit()`.
- `response_metadata` on parsed responses is owned by that parsed response and remains valid until the response's `deinit()` is called.
- Standalone `ResponseMetadata.fromHttpResponse(...)` copies must be freed with `ResponseMetadata.deinit(allocator)`.
- Streaming iterators must be deinitialized even when the caller stops reading before `[DONE]`.

## Acceptance Criteria

- [x] Examples compile.
- [x] README examples match actual API.
- [x] Public API docs do not describe unimplemented features as complete.

---

# Implemented Scope

## Required

- [x] Zig package builds on Zig `0.16.x`.
- [x] `Client.init` / `Client.deinit`.
- [x] Config with API key, base URL, timeout, referer, title.
- [x] Caller-provided `std.Io` support.
- [x] Request options.
- [x] Central HTTP layer.
- [x] JSON helpers.
- [x] Error handling.
- [x] Basic retry.
- [x] `client.models.list`.
- [x] `client.chat.completions.create`.
- [x] `client.chat.completions.stream`.
- [x] Unit tests.
- [x] Examples.

## Implemented Since v0.1.0

- [x] Broad management API coverage.
- [x] Video generation.
- [x] Guardrails.
- [x] Workspaces.

## Future Work

- OAuth helpers.
- Advanced provider routing helpers.
- Generated API compatibility layer.

---

# Compatibility Strategy

## Primary API

Handwritten, Zig-idiomatic, semver-stable.

## Optional Future Compatibility Layer

If exact Go SDK/OpenAPI parity becomes important, add an experimental namespace later:

```zig
openrouter.experimental.generated
```

Rules for any future generated compatibility layer:

- Keep generated/compat types out of the main API.
- Mark experimental APIs clearly.
- Do not let generated naming destabilize the stable API.

---

# Review Checklist Before Implementation

- [x] Confirm installed Zig version is `0.16.x` (`0.16.0` installed).
- [x] Re-check OpenRouter docs for current endpoint fields.
- [x] Re-check official Go SDK for current resource names.
- [x] Public endpoint methods return `!T`; do not expose `ApiResult(T)` in v0.1.
- [x] Resource namespaces are lightweight embedded structs initialized by `Client.init`.
- [x] HTTP transport is mockable from day one with an internal fake transport for tests.

---

# Current Repository Status

- [x] `README.md` exists.
- [x] `AGENT.md` exists.
- [x] `.gitignore` exists.
- [x] Zig package files exist.
- [x] Library implementation exists.
- [x] Tests exist.
- [x] Examples exist.
