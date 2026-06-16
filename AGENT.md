# AGENT.md

Guidance for AI coding agents working on this repository.

## Project Goal

Implement an idiomatic Zig `0.16.x` client for the OpenRouter API.

Prioritize:

- Small, readable APIs
- Explicit allocator ownership
- Typed request/response structs
- Clear error handling
- Minimal dependencies
- Tests for request construction, response parsing, and error mapping

## Zig Version

Target Zig `0.16.x`.

Before relying on language or standard-library behavior, verify it works with the installed Zig version:

```sh
zig version
zig build test
```

## Repository Conventions

- Keep source under `src/`.
- Keep tests close to the code they verify, using Zig `test` blocks where practical.
- Use `zig fmt` for formatting.
- Do not commit generated build artifacts.
- Do not commit API keys, `.env` files, logs, or local editor settings.

## API Design Guidelines

- Require callers to pass an allocator for owned data.
- Require callers to pass `std.Io` to the client; do not create a hidden/global I/O backend inside the library.
- Document ownership and lifetime of every returned value.
- Prefer typed enums/structs over loosely typed strings where practical.
- Preserve OpenRouter-compatible model IDs as strings.
- Keep transport details isolated from high-level API types.
- Make optional OpenRouter headers configurable:
  - `HTTP-Referer`
  - `X-Title`

## HTTP/API Notes

Zig `0.16.x` uses I/O as an explicit interface. The OpenRouter client should use `std.http.Client` with caller-provided `std.Io`, for example from application-owned `std.Io.Threaded`.

Do not hard-code an async runtime or event-loop backend into the library.

Normal builds should provide an application-owned `std.Io.Threaded` or another real I/O backend. Tests that only need to initialize the client can use `std.testing.io`; credentialed integration tests should keep an explicit `std.Io.Threaded` because they perform real network I/O. Avoid assuming `-fsingle-threaded` semantics inside the SDK; callers choose the I/O backend and concurrency model.

Base URL:

```text
https://openrouter.ai/api/v1
```

Common endpoints:

```text
GET  /models
POST /chat/completions
```

Authentication:

```text
Authorization: Bearer <OPENROUTER_API_KEY>
```

Use current OpenRouter documentation when implementing new endpoints or fields.

Official OpenRouter Go SDK reference for future cross-checks:

```text
https://github.com/OpenRouterTeam/go-sdk
```

## Verification Checklist

Before considering changes complete:

```sh
zig fmt .
zig build test
```

If network behavior changes, include tests that avoid requiring real API credentials unless explicitly marked as integration tests.

## Development Commands

Build and test:

```sh
zig build
zig build test
zig build examples
```

Run opt-in integration tests. Without `OPENROUTER_API_KEY`, these tests skip network work. Some tests also require `OPENROUTER_GENERATION_ID` or `OPENROUTER_MANAGEMENT_API_KEY`:

```sh
export OPENROUTER_API_KEY="sk-or-v1-..."
export OPENROUTER_GENERATION_ID="gen-..."
export OPENROUTER_MANAGEMENT_API_KEY="sk-or-v1-..."
zig build integration-test
```

Common runnable examples:

```sh
zig build run-chat
zig build run-async-chat
zig build run-stream
zig build run-list-models
zig build run-responses
zig build run-messages
zig build run-messages-stream
zig build run-embeddings
zig build run-rerank
zig build run-credits
zig build run-providers
```

See `build.zig` for the full example command list.

## Release Checklist

1. Update `src/version.zig`, `build.zig.zon`, `CHANGELOG.md`, and the install tag in `README.md`.
2. Run `zig fmt --check src/*.zig tests/*.zig examples/*.zig build.zig`.
3. Run `zig build test` and `zig build examples`.
4. Optionally run credentialed checks with `zig build integration-test`.
5. Commit the release prep, tag `vX.Y.Z`, push the tag, and create the GitHub release.

## Security

- Never hardcode API keys.
- Never log authorization headers.
- Treat request/response logs as potentially sensitive.
- Keep integration-test credentials in local environment variables only.
