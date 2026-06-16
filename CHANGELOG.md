# Changelog

## v0.7.0-dev - Unreleased

- Development resumed after `v0.6.0`.
- Switched client initialization unit tests to `std.testing.io` where no real network I/O is required.
- Added an async I/O chat example using `std.Io.concurrent`.

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
- Added auth-key authorization-code and exchange endpoints under `client.auth.keys`.
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
