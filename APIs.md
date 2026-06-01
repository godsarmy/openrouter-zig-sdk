# OpenRouter API Endpoints

Source reviewed:

- API reference overview: <https://openrouter.ai/docs/api/reference/overview>
- OpenAPI spec: <https://openrouter.ai/openapi.json>

Base URL:

```text
https://openrouter.ai/api/v1
```

Endpoint paths below are relative to the base URL.

Example: `POST /chat/completions` means `POST https://openrouter.ai/api/v1/chat/completions`.

## Core Inference Endpoints

| Method | Path | Operation | Description |
|---|---|---|---|
| POST | `/chat/completions` | `sendChatCompletionRequest` | Create a chat completion. |
| POST | `/responses` | `createResponses` | Create a response using the Responses API style. |
| POST | `/messages` | `createMessages` | Create a message. |
| POST | `/embeddings` | `createEmbeddings` | Submit an embedding request. |
| POST | `/rerank` | `createRerank` | Submit a rerank request. |
| POST | `/audio/speech` | `createAudioSpeech` | Create speech from text. |
| POST | `/audio/transcriptions` | `createAudioTranscriptions` | Create a transcription from audio. |
| POST | `/videos` | `createVideos` | Submit a video generation request. |
| GET | `/videos/{jobId}` | `getVideos` | Poll video generation job status. |
| GET | `/videos/{jobId}/content` | `listVideosContent` | Download generated video content. |
| GET | `/videos/models` | `listVideosModels` | List video generation models. |
| GET | `/embeddings/models` | `listEmbeddingsModels` | List embedding models. |

## Models, Providers, and Routing Discovery

| Method | Path | Operation | Description |
|---|---|---|---|
| GET | `/models` | `getModels` | List all models and their properties. |
| GET | `/models/count` | `listModelsCount` | Get the total count of available models. |
| GET | `/models/user` | `listModelsUser` | List models filtered by user preferences, privacy, or guardrails. |
| GET | `/models/{author}/{slug}/endpoints` | `listEndpoints` | List endpoints for a specific model. |
| GET | `/providers` | `listProviders` | List all providers. |
| GET | `/endpoints/zdr` | `listEndpointsZdr` | Preview Zero Data Retention impact on available endpoints. |

## Usage, Billing, and Generation Metadata

| Method | Path | Operation | Description |
|---|---|---|---|
| GET | `/credits` | `getCredits` | Get remaining credits. |
| POST | `/credits/coinbase` | `createCoinbaseCharge` | Create a Coinbase Commerce charge. Deprecated. |
| GET | `/generation` | `getGeneration` | Get request and usage metadata for a generation. |
| GET | `/generation/content` | `listGenerationContent` | Get stored prompt/completion content for a generation. |
| GET | `/activity` | `getUserActivity` | Get user activity grouped by endpoint. |
| GET | `/datasets/rankings-daily` | `getRankingsDaily` | Get daily token totals for top models. |

## API Keys, Auth, and BYOK

| Method | Path | Operation | Description |
|---|---|---|---|
| GET | `/key` | `getCurrentKey` | Get the current API key. |
| GET | `/keys` | `list` | List API keys. |
| POST | `/keys` | `createKeys` | Create a new API key. |
| GET | `/keys/{hash}` | `getKey` | Get a single API key. |
| PATCH | `/keys/{hash}` | `updateKeys` | Update an API key. |
| DELETE | `/keys/{hash}` | `deleteKeys` | Delete an API key. |
| POST | `/auth/keys/code` | `createAuthKeysCode` | Create an authorization code. |
| POST | `/auth/keys` | `exchangeAuthCodeForAPIKey` | Exchange an authorization code for an API key. |
| GET | `/byok` | `listBYOKKeys` | List BYOK provider credentials. |
| POST | `/byok` | `createBYOKKey` | Create a BYOK provider credential. |
| GET | `/byok/{id}` | `getBYOKKey` | Get a BYOK provider credential. |
| PATCH | `/byok/{id}` | `updateBYOKKey` | Update a BYOK provider credential. |
| DELETE | `/byok/{id}` | `deleteBYOKKey` | Delete a BYOK provider credential. |

## Guardrails

| Method | Path | Operation | Description |
|---|---|---|---|
| GET | `/guardrails` | `listGuardrails` | List guardrails. |
| POST | `/guardrails` | `createGuardrail` | Create a guardrail. |
| GET | `/guardrails/{id}` | `getGuardrail` | Get a guardrail. |
| PATCH | `/guardrails/{id}` | `updateGuardrail` | Update a guardrail. |
| DELETE | `/guardrails/{id}` | `deleteGuardrail` | Delete a guardrail. |
| GET | `/guardrails/{id}/assignments/keys` | `listGuardrailKeyAssignments` | List key assignments for a guardrail. |
| POST | `/guardrails/{id}/assignments/keys` | `bulkAssignKeysToGuardrail` | Bulk assign keys to a guardrail. |
| POST | `/guardrails/{id}/assignments/keys/remove` | `bulkUnassignKeysFromGuardrail` | Bulk unassign keys from a guardrail. |
| GET | `/guardrails/{id}/assignments/members` | `listGuardrailMemberAssignments` | List member assignments for a guardrail. |
| POST | `/guardrails/{id}/assignments/members` | `bulkAssignMembersToGuardrail` | Bulk assign members to a guardrail. |
| POST | `/guardrails/{id}/assignments/members/remove` | `bulkUnassignMembersFromGuardrail` | Bulk unassign members from a guardrail. |
| GET | `/guardrails/assignments/keys` | `listKeyAssignments` | List all key assignments. |
| GET | `/guardrails/assignments/members` | `listMemberAssignments` | List all member assignments. |

## Workspaces and Organization

| Method | Path | Operation | Description |
|---|---|---|---|
| GET | `/workspaces` | `listWorkspaces` | List workspaces. |
| POST | `/workspaces` | `createWorkspace` | Create a workspace. |
| GET | `/workspaces/{id}` | `getWorkspace` | Get a workspace. |
| PATCH | `/workspaces/{id}` | `updateWorkspace` | Update a workspace. |
| DELETE | `/workspaces/{id}` | `deleteWorkspace` | Delete a workspace. |
| POST | `/workspaces/{id}/members/add` | `bulkAddWorkspaceMembers` | Bulk add members to a workspace. |
| POST | `/workspaces/{id}/members/remove` | `bulkRemoveWorkspaceMembers` | Bulk remove members from a workspace. |
| GET | `/organization/members` | `listOrganizationMembers` | List organization members. |

## Observability

| Method | Path | Operation | Description |
|---|---|---|---|
| GET | `/observability/destinations` | `listObservabilityDestinations` | List observability destinations. |
| POST | `/observability/destinations` | `createObservabilityDestination` | Create an observability destination. |
| GET | `/observability/destinations/{id}` | `getObservabilityDestination` | Get an observability destination. |
| PATCH | `/observability/destinations/{id}` | `updateObservabilityDestination` | Update an observability destination. |
| DELETE | `/observability/destinations/{id}` | `deleteObservabilityDestination` | Delete an observability destination. |

## Preset-based Inference Endpoints

| Method | Path | Operation | Description |
|---|---|---|---|
| POST | `/presets/{slug}/chat/completions` | `createPresetsChatCompletions` | Create a preset from a chat completions request body. |
| POST | `/presets/{slug}/messages` | `createPresetsMessages` | Create a preset from a messages request body. |
| POST | `/presets/{slug}/responses` | `createPresetsResponses` | Create a preset from a responses request body. |

## Notes

- OpenRouter uses OpenAI-compatible request and response styles for core inference endpoints, with OpenRouter-specific routing and metadata features.
- The OpenAPI spec is the best source of truth for endpoint inventory because it includes endpoints beyond chat and model listing.
- This file is an endpoint catalog, not an implementation commitment for `v0.1.0`.
