# openrouter-zig

A Zig 0.16 client for the [OpenRouter API](https://openrouter.ai/docs).

This project aims to provide a small, idiomatic Zig wrapper around OpenRouter's HTTP API, including chat completions, streaming, embeddings, discovery, usage, and dataset endpoints.

## Requirements

- Zig `0.16.x`
- An OpenRouter API key

Check your Zig version:

```sh
zig version
```

## Installation

Add this package to your Zig project:

```sh
zig fetch --save https://github.com/godsarmy/openrouter-zig-sdk/archive/refs/tags/v0.2.0.tar.gz
```

Then import it from your `build.zig` dependency graph.

## Environment

Set your OpenRouter API key:

```sh
export OPENROUTER_API_KEY="sk-or-v1-..."
```

Optional OpenRouter attribution headers:

```sh
export OPENROUTER_HTTP_REFERER="https://your-site.example"
export OPENROUTER_APP_TITLE="Your App"
```

Optional integration-test inputs:

```sh
export OPENROUTER_GENERATION_ID="gen-..." # for generation / generation-content tests
export OPENROUTER_MANAGEMENT_API_KEY="sk-or-v1-..." # for credits / activity tests
```

## Usage

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

## API Scope

Implemented endpoints:

- `GET /api/v1/models`
- `POST /api/v1/chat/completions`
- `POST /api/v1/embeddings`
- `GET /api/v1/credits` (requires a management API key)
- `GET /api/v1/providers`
- `GET /api/v1/generation`
- `GET /api/v1/generation/content`
- `GET /api/v1/activity` (requires a management API key)
- `GET /api/v1/datasets/rankings-daily`
- Streaming chat completions
- Typed request and response structs
- Error mapping for OpenRouter API errors

`/datasets/rankings-daily` returns `total_tokens` as a decimal string and may include aggregated `other` rows.

## Ownership and Lifecycle

The caller provides the allocator and `std.Io` used by `Client.init`. The client owns its internal HTTP client and must be closed with `client.deinit()`.

Response values own arena-backed parsed data. Call `deinit()` on every response or stream chunk when finished:

- `ModelsListResponse.deinit()`
- `ChatCompletionResponse.deinit()`
- `EmbeddingsCreateResponse.deinit()`
- `ChatCompletionChunk.deinit()`
- `GenerationGetResponse.deinit()`
- `GenerationContentResponse.deinit()`
- `ActivityGetResponse.deinit()`
- `RankingsDailyGetResponse.deinit()`

Streaming responses use a pull iterator. Call `stream.deinit()` even if you stop reading before `[DONE]` so the HTTP request is closed.

`Client` is not thread-safe unless access is externally synchronized. Prefer one client per worker when issuing concurrent requests.

## Retry and Errors

Requests use the client retry policy by default and can override it per request with `RequestOptions.retry`. Retryable responses include `429` and common transient `5xx` OpenRouter statuses when enabled.

Public endpoint methods return `!T`. HTTP/API failures map to Zig errors such as `error.ApiError`; API keys are redacted from error/debug output.

## Examples

Build all examples:

```sh
zig build examples
```

Run individual examples:

```sh
zig build run-chat
zig build run-stream
zig build run-list-models
zig build run-embeddings
zig build run-credits
zig build run-providers
OPENROUTER_GENERATION_ID="gen-..." zig build run-generation
OPENROUTER_GENERATION_ID="gen-..." zig build run-generation-content
zig build run-activity # requires a management API key
zig build run-rankings-daily
```

## Development

Build:

```sh
zig build
```

Run tests:

```sh
zig build test
```

Run opt-in integration tests against OpenRouter. Without `OPENROUTER_API_KEY`, these tests do nothing. Some tests also require `OPENROUTER_GENERATION_ID` or `OPENROUTER_MANAGEMENT_API_KEY`:

```sh
zig build integration-test
```

Format Zig files:

```sh
zig fmt .
```

## Project Status

The SDK includes typed APIs for chat completions, streaming chat completions, embeddings, models, providers, credits, generation metadata/content, activity, and rankings datasets. Public APIs may change between minor releases while the SDK is pre-1.0.

## License

Apache-2.0. See [LICENSE](LICENSE).
