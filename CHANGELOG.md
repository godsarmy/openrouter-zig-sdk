# Changelog

## v1.1.1-dev - Unreleased

- Development resumed after `v1.1.0`.

## v1.1.0 - 2026-06-27

- Development resumed after `v1.0.0`.
- Added typed Responses API server tool support.
- Added an env-gated chat server tools integration smoke test.
- Added chat provider routing helper constructors and documented stable SemVer expectations.
- Added single-model lookup and preset read endpoints.
- Added dataset app rankings and benchmark endpoints.
- Added analytics metadata and query endpoints.
- Added workspace budget endpoints.
- Added Files API endpoints for listing, upload, metadata, deletion, and raw content downloads.

## v1.0.0 - 2026-06-19

- Stabilization resumed after `v0.9.0`.
- Typed chat server tool `tool_choice` and web search `search_context_size` before `1.0.0` stabilization.
- Typed chat `response_format.type` and server tool `user_location.type` before `1.0.0` stabilization.

## v0.9.0 - 2026-06-18

- Development resumed after `v0.8.0`.
- Added typed chat plugin support for OpenRouter Fusion.
- Removed the completed implementation plan and moved durable guidance into `AGENT.md`.
- Added a runnable Fusion plugin example.
- Added an env-gated Fusion integration smoke test.
- Made the Fusion integration smoke test non-strict by default for account or feature availability errors.
- Added typed chat server tool support for `openrouter:fusion`, `openrouter:web_search`, and `openrouter:web_fetch`.
- Added a runnable server tools example.

## v0.8.0 - 2026-06-15

- Added regression coverage for the SSE stream response/request ownership invariant.
- Hardened the opt-in Messages streaming integration smoke test to require real stream events.
- Added an opt-in chat completions streaming integration smoke test.
- Added OAuth helper methods `client.oauth.createAuthCode` and `client.oauth.exchangeAuthCodeForAPIKey` plus an example.
- Added OAuth PKCE helpers for code verifier generation and S256 challenge derivation.
- Documented the OAuth PKCE example flow and verifier persistence requirement.
- Moved advanced example guidance from `README.md` to `EXAMPLES.md`.

## v0.7.0 - 2026-06-15

- Switched client initialization unit tests to `std.testing.io` where no real network I/O is required.
- Added an async I/O chat example using `std.Io.concurrent`.
- Fixed SSE stream reader initialization after moving HTTP request state into owned stream storage.

## v0.6.0 - 2026-06-15

- Centralized SDK version and User-Agent metadata.
- Removed duplicate root exports for rankings daily item and metadata types.
- Exposed response metadata for request IDs, generation IDs, and rate-limit headers on core inference responses.
- Clarified streaming lifecycle behavior after malformed or unexpectedly closed SSE streams.
- Preserve `error.Canceled` when Zig exposes cancellation through HTTP connection reads.
- Documented threading-mode expectations for caller-provided Zig I/O backends.

## v0.5.0 - 2026-06-13

- Added Messages SSE streaming via `client.messages.stream`.
- Added BYOK provider-key management APIs.
- Added Guardrails CRUD plus key/member assignment APIs.
- Added Workspaces CRUD plus member management APIs.
- Added Observability destinations CRUD APIs.
- Added preset Messages and Responses creation APIs.
- Added opt-in management API smoke tests.
- Refactored SSE parsing for reuse.

## v0.4.0 - 2026-06-08

- Added audio speech and transcription APIs.
- Added non-streaming Responses and Anthropic-compatible Messages APIs.
- Added rerank, video generation, model endpoints, endpoint ZDR, user models, and embedding models APIs.
- Added preset chat completions support.
- Added examples for the new endpoint groups.
- Documented remaining API scope.

## v0.3.0 - 2026-06-06

- Added current API key metadata via `client.key.get` for `GET /key`.
- Added API key management endpoints under `client.keys` for listing, creating, retrieving, updating, and deleting keys.
- Added auth-key authorization-code and exchange endpoints.
- Added `client.models.count` for `GET /models/count` with `output_modalities` query support.
- Refactored endpoint implementations to reuse transport-backed request paths for real and fake transports.

## v0.2.0 - 2026-06-05

- Added providers, credits, generation metadata/content, activity, and rankings daily APIs.
- Added typed response exports and examples for new endpoints.
- Added shared query-string encoding helper.
- Expanded opt-in integration coverage for public, generation, and management-key endpoints.
- Added GitHub Actions CI for build, format, unit, example, and opt-in integration checks.

## v0.1.0

- Initial chat completions, streaming chat completions, embeddings, and models APIs.
