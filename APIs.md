# OpenRouter API Implementation Tracker

This file tracks which OpenRouter API endpoints are implemented by this Zig SDK.

Source reviewed:

- API reference overview: <https://openrouter.ai/docs/api/reference/overview>
- OpenAPI spec: <https://openrouter.ai/openapi.json>

Base URL:

```text
https://openrouter.ai/api/v1
```

Endpoint paths below are relative to the base URL.

Status legend:

- `[x]` Implemented in the SDK
- `[ ]` Not implemented yet

## Implementation Summary

| Status | Method | Path | SDK API | Notes |
|---|---|---|---|---|
| [x] | POST | `/chat/completions` | `client.chat.completions.create`, `client.chat.completions.stream` | Non-streaming and SSE streaming chat completions. |
| [x] | POST | `/embeddings` | `client.embeddings.create` | Text embedding requests. |
| [x] | GET | `/embeddings/models` | `client.embeddings.models.list` | Lists embedding models. |
| [x] | GET | `/models` | `client.models.list` | Lists available models. |
| [x] | GET | `/models/user` | `client.models.user.list` | Lists models available to the current user. |
| [x] | GET | `/models/{author}/{slug}/endpoints` | `client.models.endpoints.list` | Lists endpoints for a specific model. |
| [x] | GET | `/models/count` | `client.models.count` | Gets the total count of available models. |
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
| [ ] | POST | `/responses` | `createResponses` | Create a response using the Responses API style. |  |
| [ ] | POST | `/messages` | `createMessages` | Create a message. |  |
| [x] | POST | `/embeddings` | `createEmbeddings` | Submit an embedding request. | Implemented in `src/embeddings.zig`. |
| [ ] | POST | `/rerank` | `createRerank` | Submit a rerank request. |  |
| [ ] | POST | `/audio/speech` | `createAudioSpeech` | Create speech from text. |  |
| [ ] | POST | `/audio/transcriptions` | `createAudioTranscriptions` | Create a transcription from audio. |  |
| [ ] | POST | `/videos` | `createVideos` | Submit a video generation request. |  |
| [ ] | GET | `/videos/{jobId}` | `getVideos` | Poll video generation job status. |  |
| [ ] | GET | `/videos/{jobId}/content` | `listVideosContent` | Download generated video content. |  |
| [ ] | GET | `/videos/models` | `listVideosModels` | List video generation models. |  |
| [x] | GET | `/embeddings/models` | `listEmbeddingsModels` | List embedding models. | Implemented in `src/embeddings.zig`. |

## Models, Providers, and Routing Discovery

| Status | Method | Path | Operation | Description | SDK notes |
|---|---|---|---|---|---|
| [x] | GET | `/models` | `getModels` | List all models and their properties. | Implemented in `src/models.zig`. |
| [x] | GET | `/models/count` | `listModelsCount` | Get the total count of available models. | Implemented in `src/models.zig`. |
| [x] | GET | `/models/user` | `listModelsUser` | List models filtered by user preferences, privacy, or guardrails. | Implemented in `src/models.zig`. |
| [x] | GET | `/models/{author}/{slug}/endpoints` | `listEndpoints` | List endpoints for a specific model. | Implemented in `src/models.zig`. |
| [x] | GET | `/providers` | `listProviders` | List all providers. | Implemented in `src/providers.zig`. |
| [ ] | GET | `/endpoints/zdr` | `listEndpointsZdr` | Preview Zero Data Retention impact on available endpoints. |  |

## Usage, Billing, and Generation Metadata

| Status | Method | Path | Operation | Description | SDK notes |
|---|---|---|---|---|---|
| [x] | GET | `/credits` | `getCredits` | Get remaining credits. | Implemented in `src/credits.zig`. Requires a management API key. |
| [ ] | POST | `/credits/coinbase` | `createCoinbaseCharge` | Create a Coinbase Commerce charge. Deprecated. |  |
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
| [ ] | GET | `/byok` | `listBYOKKeys` | List BYOK provider credentials. |  |
| [ ] | POST | `/byok` | `createBYOKKey` | Create a BYOK provider credential. |  |
| [ ] | GET | `/byok/{id}` | `getBYOKKey` | Get a BYOK provider credential. |  |
| [ ] | PATCH | `/byok/{id}` | `updateBYOKKey` | Update a BYOK provider credential. |  |
| [ ] | DELETE | `/byok/{id}` | `deleteBYOKKey` | Delete a BYOK provider credential. |  |

## Guardrails

| Status | Method | Path | Operation | Description | SDK notes |
|---|---|---|---|---|---|
| [ ] | GET | `/guardrails` | `listGuardrails` | List guardrails. |  |
| [ ] | POST | `/guardrails` | `createGuardrail` | Create a guardrail. |  |
| [ ] | GET | `/guardrails/{id}` | `getGuardrail` | Get a guardrail. |  |
| [ ] | PATCH | `/guardrails/{id}` | `updateGuardrail` | Update a guardrail. |  |
| [ ] | DELETE | `/guardrails/{id}` | `deleteGuardrail` | Delete a guardrail. |  |
| [ ] | GET | `/guardrails/{id}/assignments/keys` | `listGuardrailKeyAssignments` | List key assignments for a guardrail. |  |
| [ ] | POST | `/guardrails/{id}/assignments/keys` | `bulkAssignKeysToGuardrail` | Bulk assign keys to a guardrail. |  |
| [ ] | POST | `/guardrails/{id}/assignments/keys/remove` | `bulkUnassignKeysFromGuardrail` | Bulk unassign keys from a guardrail. |  |
| [ ] | GET | `/guardrails/{id}/assignments/members` | `listGuardrailMemberAssignments` | List member assignments for a guardrail. |  |
| [ ] | POST | `/guardrails/{id}/assignments/members` | `bulkAssignMembersToGuardrail` | Bulk assign members to a guardrail. |  |
| [ ] | POST | `/guardrails/{id}/assignments/members/remove` | `bulkUnassignMembersFromGuardrail` | Bulk unassign members from a guardrail. |  |
| [ ] | GET | `/guardrails/assignments/keys` | `listKeyAssignments` | List all key assignments. |  |
| [ ] | GET | `/guardrails/assignments/members` | `listMemberAssignments` | List all member assignments. |  |

## Workspaces and Organization

| Status | Method | Path | Operation | Description | SDK notes |
|---|---|---|---|---|---|
| [ ] | GET | `/workspaces` | `listWorkspaces` | List workspaces. |  |
| [ ] | POST | `/workspaces` | `createWorkspace` | Create a workspace. |  |
| [ ] | GET | `/workspaces/{id}` | `getWorkspace` | Get a workspace. |  |
| [ ] | PATCH | `/workspaces/{id}` | `updateWorkspace` | Update a workspace. |  |
| [ ] | DELETE | `/workspaces/{id}` | `deleteWorkspace` | Delete a workspace. |  |
| [ ] | POST | `/workspaces/{id}/members/add` | `bulkAddWorkspaceMembers` | Bulk add members to a workspace. |  |
| [ ] | POST | `/workspaces/{id}/members/remove` | `bulkRemoveWorkspaceMembers` | Bulk remove members from a workspace. |  |
| [ ] | GET | `/organization/members` | `listOrganizationMembers` | List organization members. |  |

## Observability

| Status | Method | Path | Operation | Description | SDK notes |
|---|---|---|---|---|---|
| [ ] | GET | `/observability/destinations` | `listObservabilityDestinations` | List observability destinations. |  |
| [ ] | POST | `/observability/destinations` | `createObservabilityDestination` | Create an observability destination. |  |
| [ ] | GET | `/observability/destinations/{id}` | `getObservabilityDestination` | Get an observability destination. |  |
| [ ] | PATCH | `/observability/destinations/{id}` | `updateObservabilityDestination` | Update an observability destination. |  |
| [ ] | DELETE | `/observability/destinations/{id}` | `deleteObservabilityDestination` | Delete an observability destination. |  |

## Preset-based Inference Endpoints

| Status | Method | Path | Operation | Description | SDK notes |
|---|---|---|---|---|---|
| [ ] | POST | `/presets/{slug}/chat/completions` | `createPresetsChatCompletions` | Create a preset from a chat completions request body. |  |
| [ ] | POST | `/presets/{slug}/messages` | `createPresetsMessages` | Create a preset from a messages request body. |  |
| [ ] | POST | `/presets/{slug}/responses` | `createPresetsResponses` | Create a preset from a responses request body. |  |

## Notes

- Update the status checkbox and SDK notes when implementing a new endpoint.
- OpenRouter uses OpenAI-compatible request and response styles for core inference endpoints, with OpenRouter-specific routing and metadata features.
- The OpenAPI spec is the best source of truth for endpoint inventory because it includes endpoints beyond chat and model listing.
