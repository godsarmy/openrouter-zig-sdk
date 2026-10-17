---
type: Guide
title: Streaming inference APIs
description: Consume chat-completion and Responses Server-Sent Events through pull-based streams.
tags: [client, streaming, sse, chat, responses]
generated: { by: openai/gpt-6.1-sol, at: 2026-10-16T00:00:00Z }
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

Chat chunk deltas retain legacy `content` and expose additive typed `content_parts`, `tool_calls`, `reasoning`, `reasoning_details`, `annotations`, `refusal`, images, and raw JSON. Tool-call argument fragments are delivered exactly as received with their required `index`; callers that need a completed call must accumulate fragments themselves. `delta.raw` and all typed values remain valid only until that chunk is deinitialized. Generated audio is retained as raw JSON.

# Event handling and failures

The parser ignores SSE comments and non-data fields, joins multiple `data:` lines, and treats `[DONE]` as completion. It reports malformed SSE, oversized events, unexpected end of stream, cancellation, API, and allocation errors.[^sse]

Always defer `stream.deinit()` so its request, headers, prepared request, and request body are released if a loop exits early. See [memory and lifecycle](memory-and-lifecycle.md).

# Stream Responses

`client.responses.stream` sends `POST /responses` with `stream: true` and returns an owned `ResponsesStream`. Each returned `ResponsesStreamEvent` owns an event arena and must be deinitialized. The event keeps its complete parsed payload in `raw`, including unknown event types and fields; common correlation fields and scalar payloads are exposed directly.

```zig
var stream = try client.responses.stream(.{
    .model = "openai/gpt-4o-mini",
    .input = .{ .text = "Reply with only: ok" },
}, .{});
defer stream.deinit();

while (try stream.next()) |event| {
    defer event.deinit();
    if (event.textDelta()) |text| std.debug.print("{s}", .{text});
    if (event.isTerminal() and !event.isSuccess()) return error.ResponseFailed;
}
```

Function-call argument deltas are intentionally not returned by `textDelta()`; use `event.functionArgumentsDelta()`. Completed JSON arguments on `response.function_call_arguments.done` are exposed as `event.arguments`. `reasoningDelta()` accepts `response.reasoning_text.delta`, `response.reasoning_summary_text.delta`, and the documented `response.reasoning.delta` alias. `response.completed` and `response.done` are successful terminals; failed, incomplete, and `error` events are returned before the stream stops. A terminal event ends iteration even when a trailing `[DONE]` is absent. The current surface preserves item, part, response, and unknown payloads as `std.json.Value`; richer typed Responses request/input/output models remain planned. See [`responses_stream.zig`](../../examples/responses_stream.zig) or run `zig build run-responses-stream`.

[^stream]: Completion stream implementation.
[^sse]: Server-Sent Events parser.
