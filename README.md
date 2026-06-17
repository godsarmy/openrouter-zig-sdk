# openrouter-zig

A Zig 0.16 client for the [OpenRouter API](https://openrouter.ai/docs).

This project provides a small, idiomatic Zig wrapper around OpenRouter's HTTP API with explicit allocator and I/O ownership.

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
zig fetch --save https://github.com/godsarmy/openrouter-zig-sdk/archive/refs/tags/v0.7.0.tar.gz
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

The SDK covers chat completions, streaming, Messages, Responses, embeddings, rerank, audio, video, presets, model/provider discovery, usage metadata, datasets, and management APIs.

See [APIs.md](APIs.md) for the full endpoint tracker and endpoint-specific notes.

## Ownership and Lifecycle

The caller provides the allocator and `std.Io` used by `Client.init`. The client owns its internal HTTP client and must be closed with `client.deinit()`.

Response values and stream chunks own parsed data or buffered bytes. Call `deinit()` when finished. Streaming responses use a pull iterator; call `stream.deinit()` even if you stop reading early.

Inference create responses expose `response_metadata` for headers such as request ID, generation ID, and rate-limit values when OpenRouter returns them.

`Client` is not thread-safe unless access is externally synchronized. Prefer one client per worker when issuing concurrent requests.

## Retry and Errors

Requests use the client retry policy by default and can override it per request with `RequestOptions.retry`. Retryable responses include `429` and common transient `5xx` OpenRouter statuses when enabled.

Public endpoint methods return `!T`. HTTP/API failures map to Zig errors such as `error.ApiError`; API keys are redacted from error/debug output.

## Examples

Build all examples with:

```sh
zig build examples
```

See [EXAMPLES.md](EXAMPLES.md) for streaming, concurrent I/O, OAuth PKCE, endpoint examples, and integration-test notes.

## Development

Build:

```sh
zig build
```

Run tests:

```sh
zig build test
```

Run opt-in integration tests against OpenRouter. Without `OPENROUTER_API_KEY`, these tests do nothing:

```sh
zig build integration-test
```

Format Zig files:

```sh
zig fmt .
```

## Project Status

Public APIs may change between minor releases while the SDK is pre-1.0.

## License

Apache-2.0. See [LICENSE](LICENSE).
