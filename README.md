# openrouter-zig

A Zig 0.16 client for the [OpenRouter API](https://openrouter.ai/docs).

This project aims to provide a small, idiomatic Zig wrapper around OpenRouter's HTTP API, starting with chat completions and model listing.

## Requirements

- Zig `0.16.x`
- An OpenRouter API key

Check your Zig version:

```sh
zig version
```

## Installation

Add this package to your Zig project once the library API is implemented:

```sh
zig fetch --save <package-url>
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

## Planned Usage

```zig
const std = @import("std");
const openrouter = @import("openrouter");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var client = try openrouter.Client.init(.{
        .allocator = allocator,
        .api_key = std.posix.getenv("OPENROUTER_API_KEY") orelse return error.MissingApiKey,
    });
    defer client.deinit();

    const response = try client.chat(.{
        .model = "openai/gpt-4o-mini",
        .messages = &.{
            .{ .role = .user, .content = "Say hello from Zig." },
        },
    });
    defer response.deinit();

    std.debug.print("{s}\n", .{response.choices[0].message.content});
}
```

## API Scope

Initial targets:

- `GET /api/v1/models`
- `POST /api/v1/chat/completions`
- Streaming chat completions
- Typed request and response structs
- Error mapping for OpenRouter API errors

## Development

Build:

```sh
zig build
```

Run tests:

```sh
zig build test
```

Format Zig files:

```sh
zig fmt .
```

## Project Status

Early scaffolding. Public APIs may change until the first tagged release.

## License

Add a license before publishing this package.
