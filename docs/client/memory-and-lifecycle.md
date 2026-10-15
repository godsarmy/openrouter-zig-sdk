---
type: Guide
title: Memory and lifecycle
description: Manage client, response, chunk, and stream lifetimes with the caller-owned allocator and I/O backend.
tags: [client, memory, lifecycle, io]
generated: { by: openai/gpt-6.1-sol, at: 2026-10-15T22:44:12Z }
sources:
  - id: agent-rules
    resource: ../../AGENT.md
    title: Repository agent guidance
  - id: client
    resource: ../../src/client.zig
    title: Client ownership implementation
  - id: stream
    resource: ../../src/stream.zig
    title: Completion stream implementation
---

# Ownership rules

The caller supplies the allocator and `std.Io` to `Client.init`. The client creates an internal HTTP client and `Client.deinit()` releases it.[^client] Application code owns the I/O backend and must keep it alive for as long as the client needs it.[^agent-rules]

Responses, stream chunks, and streams may own parsed or buffered data. Deinitialize each value when finished; a stream must be deinitialized even when iteration stops before its terminal event.[^agent-rules]

```zig
var stream = try client.chat.completions.stream(request, .{});
defer stream.deinit();

while (try stream.next()) |chunk| {
    defer chunk.deinit();
    if (chunk.content()) |text| std.debug.print("{s}", .{text});
}
```

# Concurrency

`Client` is not thread-safe. Synchronize shared access externally or use one client per worker.[^client] See [streaming](streaming.md) for iterator behavior.

[^agent-rules]: Repository agent guidance.
[^client]: Client ownership implementation.
