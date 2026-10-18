# openrouter-zig

A Zig `0.17.x` client for the [OpenRouter API](https://openrouter.ai/docs), with explicit allocator and I/O ownership.

## Install

```sh
zig fetch --save https://github.com/godsarmy/openrouter-zig-sdk/archive/refs/tags/v1.3.0.tar.gz
```

Then import it from your `build.zig` dependency graph.

## Quick start

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

**Ownership warning:** callers own the allocator and `std.Io`; call `client.deinit()` and deinitialize returned responses, chunks, and streams. Do not share a client between threads without external synchronization.

## Documentation

- [Getting started](docs/getting-started.md)
- [Configuration](docs/client/configuration.md), [memory and lifecycle](docs/client/memory-and-lifecycle.md), [streaming](docs/client/streaming.md), and [retries and errors](docs/client/retries-and-errors.md)
- [API reference](APIs.md) and [examples](EXAMPLES.md)
- [Verification](docs/development/verification.md) and [release process](docs/development/release-process.md)

## Manual integration tests

```sh
export OPENROUTER_API_KEY="<your-api-key>"
export OPENROUTER_TEST_PROFILE=free
zig build integration-test
```

See [environment variables and profiles](docs/development/integration-testing.md). Management and paid tests are selected separately.

## License

Apache-2.0. See [LICENSE](LICENSE).
