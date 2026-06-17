# Examples

Runnable examples live in [`examples/`](examples/) and are wired through `build.zig`.

Build all examples:

```sh
zig build examples
```

## Common Examples

```sh
zig build run-chat
zig build run-fusion
zig build run-stream
zig build run-async-chat
zig build run-messages
zig build run-messages-stream
zig build run-responses
zig build run-embeddings
zig build run-rerank
```

Use `zig build --help` or inspect `build.zig` for the full list of runnable example steps.

## Concurrent I/O

Run:

```sh
zig build run-async-chat
```

The async chat example uses `std.Io.concurrent` with one `Client` per concurrent task. `Client` is not thread-safe unless access is externally synchronized.

## Fusion Plugin

Chat completions support typed plugins. Fusion can be enabled with the `openrouter/fusion` model alias and a Fusion plugin config:

Run:

```sh
zig build run-fusion
```

```zig
var response = try client.chat.completions.create(.{
    .model = "openrouter/fusion",
    .messages = &.{
        .{ .role = .user, .content = .{ .text = "Compare ridge, lasso, and elastic-net regression." } },
    },
    .plugins = &.{openrouter.ChatPlugin{ .fusion = .{
        .preset = "general-budget",
    } }},
}, .{});
defer response.deinit();
```

## OAuth PKCE

Run:

```sh
zig build run-oauth-keys
```

The OAuth example demonstrates PKCE verifier/challenge helpers plus `client.oauth.createAuthCode` and `client.oauth.exchangeAuthCodeForAPIKey`.

Create an auth code with generated PKCE values:

```sh
OPENROUTER_API_KEY="sk-or-v1-..." \
OPENROUTER_AUTH_CALLBACK_URL="https://your-app.example/callback" \
zig build run-oauth-keys
```

The example prints a generated `OPENROUTER_AUTH_CODE_VERIFIER`; persist it before redirecting the user. After OpenRouter returns an authorization code, exchange it with:

```sh
OPENROUTER_API_KEY="sk-or-v1-..." \
OPENROUTER_AUTH_CALLBACK_URL="https://your-app.example/callback" \
OPENROUTER_AUTH_CODE_VERIFIER="<printed verifier>" \
OPENROUTER_AUTH_CODE="<returned code>" \
zig build run-oauth-keys
```

You can also provide your own PKCE values:

```sh
OPENROUTER_AUTH_CODE_CHALLENGE="<challenge>"
OPENROUTER_AUTH_CODE_CHALLENGE_METHOD="S256"
OPENROUTER_AUTH_CODE_VERIFIER="<verifier>"
```

## Integration Tests

Integration tests are opt-in and skip network work unless credentials are set:

```sh
zig build integration-test
```

Common environment variables:

```sh
export OPENROUTER_API_KEY="sk-or-v1-..."
export OPENROUTER_HTTP_REFERER="https://your-site.example"
export OPENROUTER_APP_TITLE="Your App"
```

Optional integration-test inputs:

```sh
export OPENROUTER_CHAT_MODEL="openai/gpt-4o-mini"
export OPENROUTER_MESSAGES_MODEL="anthropic/claude-3.5-haiku"
export OPENROUTER_GENERATION_ID="gen-..."
export OPENROUTER_MANAGEMENT_API_KEY="sk-or-v1-..."
```
