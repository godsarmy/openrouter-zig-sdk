---
type: Guide
title: Streaming chat completions
description: Consume chat-completion Server-Sent Event chunks through the pull-based completion stream.
tags: [client, streaming, sse, chat]
generated: { by: openai/gpt-6.1-sol, at: 2026-10-15T22:44:12Z }
sources:
  - id: client
    resource: ../../src/client.zig
    title: Chat completion resource methods
  - id: stream
    resource: ../../src/stream.zig
    title: Completion stream implementation
  - id: sse
    resource: ../../src/sse.zig
    title: Server-Sent Events parser
---

# Use the pull iterator

Call `client.chat.completions.stream` with the same request shape used for a non-streaming completion. The SDK sets `stream` on its outgoing request and returns a `CompletionStream`.[^stream]

```zig
var stream = try client.chat.completions.stream(request, .{});
defer stream.deinit();

while (try stream.next()) |chunk| {
    defer chunk.deinit();
    if (chunk.content()) |text| std.debug.print("{s}", .{text});
}
```

`next()` returns `null` once the stream is done. Chunks without choices are skipped; each returned chunk owns its parsed data and requires `deinit()`.[^stream]

# Event handling and failures

The parser ignores SSE comments and non-data fields, joins multiple `data:` lines, and treats `[DONE]` as completion. It reports malformed SSE, oversized events, unexpected end of stream, cancellation, API, and allocation errors.[^sse]

Always defer `stream.deinit()` so its request, headers, prepared request, and request body are released if a loop exits early. See [memory and lifecycle](memory-and-lifecycle.md).

[^stream]: Completion stream implementation.
[^sse]: Server-Sent Events parser.
