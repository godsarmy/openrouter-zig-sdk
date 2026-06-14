# openrouter-zig

A Zig 0.16 client for the [OpenRouter API](https://openrouter.ai/docs).

This project aims to provide a small, idiomatic Zig wrapper around OpenRouter's HTTP API, including chat completions, streaming, embeddings, discovery, usage, and dataset endpoints.

## Requirements

- Zig `0.16.x`
- An OpenRouter API key

Check your Zig version:

```sh
zig version
```

## Installation

Add this package to your Zig project:

```sh
zig fetch --save https://github.com/godsarmy/openrouter-zig-sdk/archive/refs/tags/v0.5.0.tar.gz
```

Then import it from your `build.zig` dependency graph.

## Environment

Set your OpenRouter API key:

```sh
export OPENROUTER_API_KEY="sk-or-v1-..."
```

Optional OpenRouter attribution headers:

```sh
export OPENROUTER_HTTP_REFERER="https://your-site.example"
export OPENROUTER_APP_TITLE="Your App"
```

Optional integration-test inputs:

```sh
export OPENROUTER_GENERATION_ID="gen-..." # for generation / generation-content tests
export OPENROUTER_MANAGEMENT_API_KEY="sk-or-v1-..." # for credits / activity tests
```

## Usage

```zig
const std = @import("std");
const openrouter = @import("openrouter");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var threaded: std.Io.Threaded = .init_single_threaded;
    defer threaded.deinit();

    var client = try openrouter.Client.init(allocator, threaded.io(), .{
        .api_key = std.posix.getenv("OPENROUTER_API_KEY") orelse return error.MissingApiKey,
    });
    defer client.deinit();

    var response = try client.chat.completions.create(.{
        .model = "openai/gpt-4o-mini",
        .messages = &.{
            .{ .role = .user, .content = .{ .text = "Say hello from Zig." } },
        },
    }, .{});
    defer response.deinit();

    std.debug.print("{s}\n", .{response.choices[0].message.content.?});
}
```

## API Scope

Implemented endpoints:

- `POST /api/v1/audio/speech`
- `POST /api/v1/audio/transcriptions`
- `POST /api/v1/responses`
- `POST /api/v1/messages`
- `GET /api/v1/models`
- `GET /api/v1/models/user`
- `GET /api/v1/models/{author}/{slug}/endpoints`
- `GET /api/v1/endpoints/zdr`
- `GET /api/v1/models/count`
- `POST /api/v1/videos`
- `GET /api/v1/videos/{jobId}`
- `GET /api/v1/videos/{jobId}/content`
- `GET /api/v1/videos/models`
- `POST /api/v1/presets/{slug}/chat/completions`
- `POST /api/v1/presets/{slug}/messages`
- `POST /api/v1/presets/{slug}/responses`
- `POST /api/v1/rerank`
- `POST /api/v1/chat/completions`
- `POST /api/v1/embeddings`
- `GET /api/v1/embeddings/models`
- `GET /api/v1/byok` (requires a management API key)
- `POST /api/v1/byok` (requires a management API key)
- `GET /api/v1/byok/{id}` (requires a management API key)
- `PATCH /api/v1/byok/{id}` (requires a management API key)
- `DELETE /api/v1/byok/{id}` (requires a management API key)
- `GET /api/v1/guardrails` (requires a management API key)
- `POST /api/v1/guardrails` (requires a management API key)
- `GET /api/v1/guardrails/{id}` (requires a management API key)
- `PATCH /api/v1/guardrails/{id}` (requires a management API key)
- `DELETE /api/v1/guardrails/{id}` (requires a management API key)
- Guardrail key and member assignment endpoints (requires a management API key)
- Workspace CRUD and member endpoints (requires a management API key)
- Observability destinations CRUD (requires a management API key)
- `GET /api/v1/organization/members` (requires a management API key)
- `GET /api/v1/credits` (requires a management API key)
- `GET /api/v1/key`
- `GET /api/v1/providers`
- `GET /api/v1/generation`
- `GET /api/v1/generation/content`
- `GET /api/v1/activity` (requires a management API key)
- `GET /api/v1/datasets/rankings-daily`
- Streaming chat completions
- Streaming Messages events
- Typed request and response structs
- Error mapping for OpenRouter API errors

`/datasets/rankings-daily` returns `total_tokens` as a decimal string and may include aggregated `other` rows.
`/models/count` accepts optional `output_modalities` values such as `text`, `image`, `audio`, `embeddings`, comma-separated combinations, or `all`; OpenRouter defaults to `text`.
`client.responses.create` implements non-streaming `/responses`; use `RequestOptions.extra_headers` with `X-OpenRouter-Experimental-Metadata: enabled` to receive `openrouter_metadata` when OpenRouter provides it.
`client.messages.create` implements non-streaming Anthropic-compatible `/messages`; `client.messages.stream` forces `stream: true` and returns parsed SSE events. Use `RequestOptions.extra_headers` with `X-OpenRouter-Experimental-Metadata: enabled` to receive `openrouter_metadata` when OpenRouter provides it. Less common provider/model-specific fields can be sent through `extra_body`; `stream` in `extra_body` is ignored so the SDK method controls streaming behavior.
Preset-based inference is available through `client.presets.chat.completions.create`, `client.presets.messages.create`, and `client.presets.responses.create`.

## Ownership and Lifecycle

The caller provides the allocator and `std.Io` used by `Client.init`. The client owns its internal HTTP client and must be closed with `client.deinit()`.

Response values own their parsed JSON data or buffered raw bytes. Call `deinit()` on every response or stream chunk when finished:

- `AudioSpeechCreateResponse.deinit()`
- `AudioTranscriptionsCreateResponse.deinit()`
- `ResponsesCreateResponse.deinit()`
- `MessagesCreateResponse.deinit()`
- `MessagesStreamEvent.deinit()`
- `ModelsListResponse.deinit()`
- `ModelsUserListResponse.deinit()`
- `ModelsEndpointsListResponse.deinit()`
- `EndpointsZdrListResponse.deinit()`
- `ModelsCountResponse.deinit()`
- `VideoJobResponse.deinit()`
- `VideoContentResponse.deinit()`
- `VideoModelsListResponse.deinit()`
- `PresetChatCompletionsCreateResponse.deinit()`
- `RerankCreateResponse.deinit()`
- `ChatCompletionResponse.deinit()`
- `EmbeddingsCreateResponse.deinit()`
- `EmbeddingsModelsListResponse.deinit()`
- `ChatCompletionChunk.deinit()`
- `GenerationGetResponse.deinit()`
- `GenerationContentResponse.deinit()`
- `ActivityGetResponse.deinit()`
- `KeyGetResponse.deinit()`
- `CreditsGetResponse.deinit()`
- `ProvidersListResponse.deinit()`
- `PresetCreateResponse.deinit()` / preset chat, Messages, and Responses create responses
- Auth-key create/exchange response `deinit()` methods
- API key list/create/get/update/delete response `deinit()` methods
- BYOK list/create/get/update/delete response `deinit()` methods
- Guardrails list/create/get/update/delete, assignment list, and bulk assignment response `deinit()` methods
- Workspace list/create/get/update/delete and bulk member response `deinit()` methods
- `OrganizationMembersListResponse.deinit()`
- `RankingsDailyGetResponse.deinit()`
- Observability destination list/create/get/update/delete response `deinit()` methods

Inference create responses expose `response_metadata` with captured response headers such as request ID, generation ID, and rate-limit values when OpenRouter returns them. This metadata is owned by the parsed response and remains valid until that response's `deinit()` is called.

Streaming responses use a pull iterator. Call `stream.deinit()` even if you stop reading before `[DONE]` so the HTTP request is closed.

`Client` is not thread-safe unless access is externally synchronized. Prefer one client per worker when issuing concurrent requests.

## Retry and Errors

Requests use the client retry policy by default and can override it per request with `RequestOptions.retry`. Retryable responses include `429` and common transient `5xx` OpenRouter statuses when enabled.

Public endpoint methods return `!T`. HTTP/API failures map to Zig errors such as `error.ApiError`; API keys are redacted from error/debug output.

## Examples

Build all examples:

```sh
zig build examples
```

Run individual examples:

```sh
zig build run-chat
zig build run-stream
zig build run-list-models
zig build run-list-user-models
zig build run-list-model-endpoints
zig build run-endpoints-zdr
zig build run-models-count
zig build run-videos
zig build run-video-models
zig build run-preset-chat-completions
zig build run-rerank
zig build run-audio-speech
zig build run-audio-transcriptions
zig build run-responses
zig build run-messages
zig build run-messages-stream
zig build run-embeddings
zig build run-embeddings-models
zig build run-byok # requires a management API key
zig build run-guardrails # requires a management API key
zig build run-workspaces # requires a management API key
zig build run-observability-destinations # requires a management API key
zig build run-organization-members # requires a management API key
zig build run-credits
zig build run-providers
OPENROUTER_GENERATION_ID="gen-..." zig build run-generation
OPENROUTER_GENERATION_ID="gen-..." zig build run-generation-content
zig build run-activity # requires a management API key
zig build run-rankings-daily
```

## Development

Build:

```sh
zig build
```

Run tests:

```sh
zig build test
```

Run opt-in integration tests against OpenRouter. Without `OPENROUTER_API_KEY`, these tests do nothing. Some tests also require `OPENROUTER_GENERATION_ID` or `OPENROUTER_MANAGEMENT_API_KEY`:

```sh
zig build integration-test
```

Format Zig files:

```sh
zig fmt .
```

Release checklist:

1. Update `src/version.zig`, `build.zig.zon`, `CHANGELOG.md`, and the install tag in this README.
2. Run `zig fmt --check src/*.zig tests/*.zig examples/*.zig build.zig`.
3. Run `zig build test` and `zig build examples`.
4. Optionally run credentialed checks with `zig build integration-test`.
5. Commit the release prep, tag `vX.Y.Z`, push the tag, and create the GitHub release.

## Project Status

The SDK includes typed APIs for chat completions, streaming chat completions, Responses API creation, Anthropic-compatible Messages API creation and streaming, preset chat/Messages/Responses creation, audio speech, audio transcriptions, reranking, embeddings, embedding model discovery, video generation, models, user model discovery, model endpoint discovery, ZDR endpoint discovery, providers, credits, current key metadata, API key management, BYOK provider-key management, guardrails, workspaces, organization members, observability destinations, generation metadata/content, activity, and rankings datasets. Public APIs may change between minor releases while the SDK is pre-1.0.

## License

Apache-2.0. See [LICENSE](LICENSE).
