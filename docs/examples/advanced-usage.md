---
type: Usage Guide
title: Advanced runnable-example usage
description: Preserved guidance for concurrent I/O, Fusion, server tools, provider routing, OAuth PKCE, and opt-in integration tests.
tags: [examples, concurrency, fusion, tools, oauth, routing]
generated: { by: openai/gpt-6.1-sol, at: 2026-10-15T22:45:26Z }
sources:
  - id: examples-guide
    resource: ../../examples/
    title: Runnable example sources
---

# Concurrent I/O

Run `zig build run-async-chat`. It uses `std.Io.concurrent` and one `Client` per concurrent task. A `Client` is not thread-safe unless callers synchronize access externally.

# Fusion plugin

Run `zig build run-fusion`. Chat supports typed plugins; use model alias `openrouter/fusion` and `openrouter.ChatPlugin{ .fusion = .{ .preset = "general-budget" } }` in a completion request.

# Server tools

Run `zig build run-server-tools`; choose a tool with `OPENROUTER_SERVER_TOOL=web_fetch` or `OPENROUTER_SERVER_TOOL=fusion`. Typed chat tools include `.fusion`, `.web_search`, and `.web_fetch`; use `.raw` for a future tool shape. The Responses API accepts the analogous `openrouter.ResponsesServerTool` shapes.

# Provider routing

For common chat policies, set `provider`, for example `openrouter.ChatProviderRouting.only(&.{ "openai", "azure" }).withRequiredParameters()`.

# OAuth PKCE

Run `zig build run-oauth-keys` with `OPENROUTER_API_KEY` and `OPENROUTER_AUTH_CALLBACK_URL`. The example creates PKCE verifier/challenge values and calls `client.oauth.createAuthCode`; persist the printed `OPENROUTER_AUTH_CODE_VERIFIER` before redirecting. On return, supply that verifier and `OPENROUTER_AUTH_CODE` to exchange it with `client.oauth.exchangeAuthCodeForAPIKey`. Custom values may be supplied through `OPENROUTER_AUTH_CODE_CHALLENGE`, `OPENROUTER_AUTH_CODE_CHALLENGE_METHOD=S256`, and `OPENROUTER_AUTH_CODE_VERIFIER`.

# Integration tests

`zig build integration-test` is opt-in and skips network work without credentials. Common inputs are `OPENROUTER_API_KEY`, `OPENROUTER_HTTP_REFERER`, and `OPENROUTER_APP_TITLE`; optional inputs include chat/messages model overrides, Fusion and server-tool test/strict flags, `OPENROUTER_GENERATION_ID`, and `OPENROUTER_MANAGEMENT_API_KEY`.
