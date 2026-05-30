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
- Document ownership and lifetime of every returned value.
- Prefer typed enums/structs over loosely typed strings where practical.
- Preserve OpenRouter-compatible model IDs as strings.
- Keep transport details isolated from high-level API types.
- Make optional OpenRouter headers configurable:
  - `HTTP-Referer`
  - `X-Title`

## HTTP/API Notes

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

## Verification Checklist

Before considering changes complete:

```sh
zig fmt .
zig build test
```

If network behavior changes, include tests that avoid requiring real API credentials unless explicitly marked as integration tests.

## Security

- Never hardcode API keys.
- Never log authorization headers.
- Treat request/response logs as potentially sensitive.
- Keep integration-test credentials in local environment variables only.
