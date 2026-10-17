---
type: Usage Guide
title: Advanced runnable-example usage
description: Preserved guidance for concurrent I/O, Fusion, server tools, provider routing, OAuth PKCE, and opt-in integration tests.
tags: [examples, concurrency, fusion, tools, oauth, routing]
generated: { by: openai/gpt-6.1-sol, at: 2026-10-16T00:00:00Z }
sources:
  - id: examples-guide
    resource: ../../examples/
    title: Runnable example sources
  - id: chat-routing
    resource: ../../src/chat.zig
    title: Chat provider routing types
  - id: provider-selection
    resource: https://openrouter.ai/docs/guides/routing/provider-selection
    title: Provider selection guide
---

# Concurrent I/O

Run `zig build run-async-chat`. It uses `std.Io.concurrent` and one `Client` per concurrent task. A `Client` is not thread-safe unless callers synchronize access externally.

# Fusion plugin

Run `zig build run-fusion`. Chat supports typed plugins; use model alias `openrouter/fusion` and `openrouter.ChatPlugin{ .fusion = .{ .preset = "general-budget" } }` in a completion request.

# Server tools

Run `zig build run-server-tools`; choose a tool with `OPENROUTER_SERVER_TOOL=web_fetch` or `OPENROUTER_SERVER_TOOL=fusion`. Typed chat tools include `.fusion`, `.web_search`, and `.web_fetch`; use `.raw` for a future tool shape. The Responses API accepts the analogous `openrouter.ResponsesServerTool` shapes.

# Provider routing

For common chat policies, set `provider`, for example `openrouter.ChatProviderRouting.only(&.{ "openai", "azure" }).withRequiredParameters()`. Hard filters use `only_providers` or `ignore`; preferred throughput and maximum latency are soft selection preferences (a scalar is p50, or provide percentile criteria).

```zig
.provider = .{
    .data_collection = .deny,
    .zdr = true,
    .only_providers = &.{ "openai", "azure" },
    .sort = .{ .config = .{ .by = .latency, .partition = .model } },
    .preferred_max_latency = .{ .percentiles = .{ .p50 = 1.5, .p90 = 3.0 } },
    .max_price = .{ .prompt = .{ .number = 2.0 }, .completion = .{ .string = "8" } },
}
```

Latency is in seconds and throughput is tokens per second. `max_price.prompt` and `.completion` are USD per million tokens; `request` is USD per request and `image` is USD per image. The service guide describes numeric prices while the schema specifies strings, so the typed API accepts both. `provider.options` is a borrowed `std.json.Value` object keyed by provider slug and is serialized only beneath `provider.options`; it must remain valid until request serialization finishes. Non-object options are rejected during serialization. Provider fields on other endpoint request types remain raw JSON compatibility fields.

# OAuth PKCE

Run `zig build run-oauth-keys` with `OPENROUTER_API_KEY` and `OPENROUTER_AUTH_CALLBACK_URL`. The example creates PKCE verifier/challenge values and calls `client.oauth.createAuthCode`; persist the printed `OPENROUTER_AUTH_CODE_VERIFIER` before redirecting. On return, supply that verifier and `OPENROUTER_AUTH_CODE` to exchange it with `client.oauth.exchangeAuthCodeForAPIKey`. Custom values may be supplied through `OPENROUTER_AUTH_CODE_CHALLENGE`, `OPENROUTER_AUTH_CODE_CHALLENGE_METHOD=S256`, and `OPENROUTER_AUTH_CODE_VERIFIER`.

# Integration tests

`zig build integration-test` is opt-in and skips network work without credentials. Common inputs are `OPENROUTER_API_KEY`, `OPENROUTER_HTTP_REFERER`, and `OPENROUTER_APP_TITLE`; optional inputs include chat/messages model overrides, Fusion and server-tool test/strict flags, `OPENROUTER_GENERATION_ID`, and `OPENROUTER_MANAGEMENT_API_KEY`.
