# OpenRouter API Implementation Tracker

This file tracks which OpenRouter API endpoints are implemented by this Zig SDK.

Source reviewed:

- API reference overview: <https://openrouter.ai/docs/api/reference/overview>
- OpenAPI spec: <https://openrouter.ai/openapi.json>
- Audio API announcement: <https://openrouter.ai/blog/announcing-audio-apis>

Base URL:

```text
https://openrouter.ai/api/v1
```

Endpoint paths below are relative to the base URL.

Status legend:

- `[x]` Implemented in the SDK
- `[ ]` Not implemented yet
- `[deprecated]` Deprecated upstream and intentionally not implemented

## Implementation Summary

| Status | Method | Path | SDK API | Notes |
|---|---|---|---|---|
| [x] | POST | `/chat/completions` | `client.chat.completions.create`, `client.chat.completions.stream` | Non-streaming and SSE streaming chat completions. |
| [x] | POST | `/responses` | `client.responses.create` | OpenAI-compatible Responses API. |
| [x] | POST | `/messages` | `client.messages.create` | Anthropic-compatible Messages API. |
| [x] | POST | `/audio/speech` | `client.audio.speech.create` | Creates raw audio bytes from text. |
| [x] | POST | `/audio/transcriptions` | `client.audio.transcriptions.create` | Transcribes base64-encoded audio to text. |
| [x] | POST | `/rerank` | `client.rerank.create` | Reranks documents for a query. |
| [x] | POST | `/embeddings` | `client.embeddings.create` | Text embedding requests. |
| [x] | GET | `/embeddings/models` | `client.embeddings.models.list` | Lists embedding models. |
| [x] | GET | `/models` | `client.models.list` | Lists available models. |
| [x] | GET | `/models/user` | `client.models.user.list` | Lists models available to the current user. |
| [x] | GET | `/models/{author}/{slug}/endpoints` | `client.models.endpoints.list` | Lists endpoints for a specific model. |
| [x] | GET | `/endpoints/zdr` | `client.endpoints.zdr.list` | Previews Zero Data Retention endpoint availability. |
| [x] | GET | `/models/count` | `client.models.count` | Gets the total count of available models. |
| [x] | POST | `/videos` | `client.videos.create` | Creates a video generation job. |
| [x] | GET | `/videos/{jobId}` | `client.videos.get` | Polls video generation job status. |
| [x] | GET | `/videos/{jobId}/content` | `client.videos.content` | Downloads generated video content. |
| [x] | GET | `/videos/models` | `client.videos.models.list` | Lists video generation models. |
| [x] | POST | `/presets/{slug}/chat/completions` | `client.presets.chat.completions.create` | Creates a preset from a chat completions request body. |
| [x] | POST | `/presets/{slug}/messages` | `client.presets.messages.create` | Creates a preset from a messages request body. |
| [x] | POST | `/presets/{slug}/responses` | `client.presets.responses.create` | Creates a preset from a responses request body. |
| [x] | GET | `/credits` | `client.credits.get` | Gets remaining credits and usage. Requires a management API key. |
| [x] | GET | `/providers` | `client.providers.list` | Lists available providers. |
| [x] | GET | `/generation` | `client.generation.get` | Gets request and usage metadata for a generation. |
| [x] | GET | `/generation/content` | `client.generation.content` | Gets stored prompt/completion content for a generation. |
| [x] | GET | `/activity` | `client.activity.get` | Gets user activity grouped by endpoint. Requires a management API key. |
| [x] | GET | `/datasets/rankings-daily` | `client.datasets.rankings_daily.get` | Gets daily token totals for top models. |
| [x] | GET | `/key` | `client.key.get` | Gets metadata for the current API key. |

## Core Inference Endpoints

| Status | Method | Path | Operation | Description | SDK notes |
|---|---|---|---|---|---|
| [x] | POST | `/chat/completions` | `sendChatCompletionRequest` | Create a chat completion. | Implemented in `src/chat.zig` and `src/stream.zig`. |
| [x] | POST | `/responses` | `createResponses` | Create a response using the Responses API style. | Implemented in `src/responses.zig`. Non-streaming only; do not pass `stream: true`. |
| [x] | POST | `/messages` | `createMessages` | Create a message. | Implemented in `src/messages.zig`, including `client.messages.stream` for SSE events. |
| [x] | POST | `/embeddings` | `createEmbeddings` | Submit an embedding request. | Implemented in `src/embeddings.zig`. |
| [x] | POST | `/rerank` | `createRerank` | Submit a rerank request. | Implemented in `src/rerank.zig`. |
| [x] | POST | `/audio/speech` | `createAudioSpeech` | Create speech from text. | Implemented in `src/audio.zig`. Returns raw audio bytes such as MP3/PCM. |
| [x] | POST | `/audio/transcriptions` | `createAudioTranscriptions` | Create a transcription from audio. | Implemented in `src/audio.zig`. Accepts base64 audio and returns text. |
| [x] | POST | `/videos` | `createVideos` | Submit a video generation request. | Implemented in `src/videos.zig`. |
| [x] | GET | `/videos/{jobId}` | `getVideos` | Poll video generation job status. | Implemented in `src/videos.zig`. |
| [x] | GET | `/videos/{jobId}/content` | `listVideosContent` | Download generated video content. | Implemented in `src/videos.zig`. |
| [x] | GET | `/videos/models` | `listVideosModels` | List video generation models. | Implemented in `src/videos.zig`. |
| [x] | GET | `/embeddings/models` | `listEmbeddingsModels` | List embedding models. | Implemented in `src/embeddings.zig`. |

## Models, Providers, and Routing Discovery

| Status | Method | Path | Operation | Description | SDK notes |
|---|---|---|---|---|---|
| [x] | GET | `/models` | `getModels` | List all models and their properties. | Implemented in `src/models.zig`. |
| [x] | GET | `/models/count` | `listModelsCount` | Get the total count of available models. | Implemented in `src/models.zig`. |
| [x] | GET | `/models/user` | `listModelsUser` | List models filtered by user preferences, privacy, or guardrails. | Implemented in `src/models.zig`. |
| [x] | GET | `/models/{author}/{slug}/endpoints` | `listEndpoints` | List endpoints for a specific model. | Implemented in `src/models.zig`. |
| [x] | GET | `/providers` | `listProviders` | List all providers. | Implemented in `src/providers.zig`. |
| [x] | GET | `/endpoints/zdr` | `listEndpointsZdr` | Preview Zero Data Retention impact on available endpoints. | Implemented in `src/endpoints.zig`. |

## Usage, Billing, and Generation Metadata

| Status | Method | Path | Operation | Description | SDK notes |
|---|---|---|---|---|---|
| [x] | GET | `/credits` | `getCredits` | Get remaining credits. | Implemented in `src/credits.zig`. Requires a management API key. |
| [deprecated] | POST | `/credits/coinbase` | `createCoinbaseCharge` | Create a Coinbase Commerce charge. Deprecated. | Intentionally not implemented. |
| [x] | GET | `/generation` | `getGeneration` | Get request and usage metadata for a generation. | Implemented in `src/generation.zig`. |
| [x] | GET | `/generation/content` | `listGenerationContent` | Get stored prompt/completion content for a generation. | Implemented in `src/generation.zig`. |
| [x] | GET | `/activity` | `getUserActivity` | Get user activity grouped by endpoint. | Implemented in `src/activity.zig`. Requires a management API key. |
| [x] | GET | `/datasets/rankings-daily` | `getRankingsDaily` | Get daily token totals for top models. | Implemented in `src/datasets.zig`. |

## API Keys, Auth, and BYOK

| Status | Method | Path | Operation | Description | SDK notes |
|---|---|---|---|---|---|
| [x] | GET | `/key` | `getCurrentKey` | Get the current API key. | Implemented in `src/key.zig`. |
| [x] | GET | `/keys` | `list` | List API keys. | Implemented in `src/keys.zig` as `client.keys.list`. |
| [x] | POST | `/keys` | `create` | Create a new API key. | Implemented in `src/keys.zig` as `client.keys.create`. |
| [x] | GET | `/keys/{hash}` | `get` | Get a single API key. | Implemented in `src/keys.zig` as `client.keys.get`. |
| [x] | PATCH | `/keys/{hash}` | `update` | Update an API key. | Implemented in `src/keys.zig` as `client.keys.update`. |
| [x] | DELETE | `/keys/{hash}` | `delete` | Delete an API key. | Implemented in `src/keys.zig` as `client.keys.delete`. |
| [x] | POST | `/auth/keys/code` | `createAuthKeysCode` | Create an authorization code. | Implemented in `src/auth_keys.zig` as `client.auth.code.create`. |
| [x] | POST | `/auth/keys` | `exchangeAuthCodeForAPIKey` | Exchange an authorization code for an API key. | Implemented in `src/auth_keys.zig` as `client.auth.exchange`. |
| [x] | GET | `/byok` | `listBYOKKeys` | List BYOK provider credentials. | Implemented in `src/byok.zig`. Requires management auth. |
| [x] | POST | `/byok` | `createBYOKKey` | Create a BYOK provider credential. | Implemented in `src/byok.zig`; raw provider keys are request-only and not represented in responses. |
| [x] | GET | `/byok/{id}` | `getBYOKKey` | Get a BYOK provider credential. | Implemented in `src/byok.zig`. |
| [x] | PATCH | `/byok/{id}` | `updateBYOKKey` | Update a BYOK provider credential. | Implemented in `src/byok.zig`. |
| [x] | DELETE | `/byok/{id}` | `deleteBYOKKey` | Delete a BYOK provider credential. | Implemented in `src/byok.zig`. |

## Guardrails

| Status | Method | Path | Operation | Description | SDK notes |
|---|---|---|---|---|---|
| [x] | GET | `/guardrails` | `listGuardrails` | List guardrails. | Implemented in `src/guardrails.zig`. Requires management auth. |
| [x] | POST | `/guardrails` | `createGuardrail` | Create a guardrail. | Implemented in `src/guardrails.zig`. |
| [x] | GET | `/guardrails/{id}` | `getGuardrail` | Get a guardrail. | Implemented in `src/guardrails.zig`. |
| [x] | PATCH | `/guardrails/{id}` | `updateGuardrail` | Update a guardrail. | Implemented in `src/guardrails.zig`. |
| [x] | DELETE | `/guardrails/{id}` | `deleteGuardrail` | Delete a guardrail. | Implemented in `src/guardrails.zig`. |
| [x] | GET | `/guardrails/{id}/assignments/keys` | `listGuardrailKeyAssignments` | List key assignments for a guardrail. | Implemented in `src/guardrails.zig`. |
| [x] | POST | `/guardrails/{id}/assignments/keys` | `bulkAssignKeysToGuardrail` | Bulk assign keys to a guardrail. | Implemented in `src/guardrails.zig`. |
| [x] | POST | `/guardrails/{id}/assignments/keys/remove` | `bulkUnassignKeysFromGuardrail` | Bulk unassign keys from a guardrail. | Implemented in `src/guardrails.zig`. |
| [x] | GET | `/guardrails/{id}/assignments/members` | `listGuardrailMemberAssignments` | List member assignments for a guardrail. | Implemented in `src/guardrails.zig`. |
| [x] | POST | `/guardrails/{id}/assignments/members` | `bulkAssignMembersToGuardrail` | Bulk assign members to a guardrail. | Implemented in `src/guardrails.zig`. |
| [x] | POST | `/guardrails/{id}/assignments/members/remove` | `bulkUnassignMembersFromGuardrail` | Bulk unassign members from a guardrail. | Implemented in `src/guardrails.zig`. |
| [x] | GET | `/guardrails/assignments/keys` | `listKeyAssignments` | List all key assignments. | Implemented in `src/guardrails.zig`. |
| [x] | GET | `/guardrails/assignments/members` | `listMemberAssignments` | List all member assignments. | Implemented in `src/guardrails.zig`. |

## Workspaces and Organization

| Status | Method | Path | Operation | Description | SDK notes |
|---|---|---|---|---|---|
| [x] | GET | `/workspaces` | `listWorkspaces` | List workspaces. | Implemented in `src/workspaces.zig`. Requires management auth. |
| [x] | POST | `/workspaces` | `createWorkspace` | Create a workspace. | Implemented in `src/workspaces.zig`. |
| [x] | GET | `/workspaces/{id}` | `getWorkspace` | Get a workspace. | Implemented in `src/workspaces.zig`. |
| [x] | PATCH | `/workspaces/{id}` | `updateWorkspace` | Update a workspace. | Implemented in `src/workspaces.zig`. |
| [x] | DELETE | `/workspaces/{id}` | `deleteWorkspace` | Delete a workspace. | Implemented in `src/workspaces.zig`. |
| [x] | POST | `/workspaces/{id}/members/add` | `bulkAddWorkspaceMembers` | Bulk add members to a workspace. | Implemented in `src/workspaces.zig`. |
| [x] | POST | `/workspaces/{id}/members/remove` | `bulkRemoveWorkspaceMembers` | Bulk remove members from a workspace. | Implemented in `src/workspaces.zig`. |
| [x] | GET | `/organization/members` | `listOrganizationMembers` | List organization members. | Implemented in `src/organization.zig`. Requires management auth. |

## Observability

| Status | Method | Path | Operation | Description | SDK notes |
|---|---|---|---|---|---|
| [x] | GET | `/observability/destinations` | `listObservabilityDestinations` | List observability destinations. | Implemented in `src/observability.zig`. Requires management auth. |
| [x] | POST | `/observability/destinations` | `createObservabilityDestination` | Create an observability destination. | Implemented in `src/observability.zig`. Requires management auth. |
| [x] | GET | `/observability/destinations/{id}` | `getObservabilityDestination` | Get an observability destination. | Implemented in `src/observability.zig`. Requires management auth. |
| [x] | PATCH | `/observability/destinations/{id}` | `updateObservabilityDestination` | Update an observability destination. | Implemented in `src/observability.zig`. Requires management auth. |
| [x] | DELETE | `/observability/destinations/{id}` | `deleteObservabilityDestination` | Delete an observability destination. | Implemented in `src/observability.zig`. Requires management auth. |

## Preset-based Inference Endpoints

| Status | Method | Path | Operation | Description | SDK notes |
|---|---|---|---|---|---|
| [x] | POST | `/presets/{slug}/chat/completions` | `createPresetsChatCompletions` | Create a preset from a chat completions request body. | Implemented in `src/presets.zig`. |
| [x] | POST | `/presets/{slug}/messages` | `createPresetsMessages` | Create a preset from a messages request body. | Implemented in `src/presets.zig`. |
| [x] | POST | `/presets/{slug}/responses` | `createPresetsResponses` | Create a preset from a responses request body. | Implemented in `src/presets.zig`. |

## Notes

- Update the status checkbox and SDK notes when implementing a new endpoint.
- OpenRouter uses OpenAI-compatible request and response styles for core inference endpoints, with OpenRouter-specific routing and metadata features.
- The OpenAPI spec is the best source of truth for endpoint inventory because it includes endpoints beyond chat and model listing.
- `/datasets/rankings-daily` returns `total_tokens` as a decimal string and may include aggregated `other` rows.
- `/models/count` accepts optional `output_modalities` values such as `text`, `image`, `audio`, `embeddings`, comma-separated combinations, or `all`; OpenRouter defaults to `text`.
- `client.responses.create` implements non-streaming `/responses`; use `RequestOptions.extra_headers` with `X-OpenRouter-Experimental-Metadata: enabled` to receive `openrouter_metadata` when OpenRouter provides it.
- `client.messages.create` implements non-streaming Anthropic-compatible `/messages`; `client.messages.stream` forces `stream: true` and returns parsed SSE events. Use `RequestOptions.extra_headers` with `X-OpenRouter-Experimental-Metadata: enabled` to receive `openrouter_metadata` when OpenRouter provides it. Less common provider/model-specific fields can be sent through `extra_body`; `stream` in `extra_body` is ignored so the SDK method controls streaming behavior.
- Preset-based inference is available through `client.presets.chat.completions.create`, `client.presets.messages.create`, and `client.presets.responses.create`.
