---
type: Guide
title: Getting started
description: Install openrouter-zig and make a first chat-completions request.
tags: [getting-started, client, chat]
generated: { by: openai/gpt-6.1-sol, at: 2026-10-15T22:44:12Z }
sources:
  - id: readme
    resource: ../README.md
    title: Repository README
  - id: client
    resource: ../src/client.zig
    title: Client implementation
---

# Install

Use Zig's package fetch command with the release archive shown in the repository README. The package targets Zig `0.17.x`.[^readme]

# Initialize and call chat completions

Pass an allocator, an application-owned `std.Io`, and a non-empty API key to `Client.init`. `Config.base_url` defaults to `https://openrouter.ai/api/v1`.[^client]

```zig
var client = try openrouter.Client.init(allocator, threaded.io(), .{
    .api_key = std.posix.getenv("OPENROUTER_API_KEY") orelse return error.MissingApiKey,
});
defer client.deinit();

var response = try client.chat.completions.create(.{
    .model = "openai/gpt-4o-mini",
    .messages = &.{.{ .role = .user, .content = .{ .text = "Hello" } }},
}, .{});
defer response.deinit();
```

Read [configuration](client/configuration.md) before customizing a client and [memory and lifecycle](client/memory-and-lifecycle.md) before retaining returned values. API coverage is indexed in [API reference](api/index.md); runnable programs are indexed in [examples](examples/index.md).

[^readme]: Repository README.
[^client]: Client implementation.
