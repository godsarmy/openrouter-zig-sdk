---
type: API Reference
title: OpenRouter Zig endpoint coverage
description: Canonical categorized inventory of the 91 HTTP endpoint operations exported by the client.
tags: [api, endpoints, coverage]
generated: { by: openai/gpt-5.6-terra, at: 2026-10-17T00:00:00Z }
sources:
  - id: client
    resource: ../../src/client.zig
    title: Client resource registration
  - id: workspaces
    resource: ../../src/workspaces.zig
    title: Workspace management API
  - id: benchmarks
    resource: ../../src/benchmarks.zig
    title: Unified benchmarks API
  - id: classifications
    resource: ../../src/classifications.zig
    title: Task classifications API
  - id: datasets
    resource: ../../src/datasets.zig
    title: Dataset APIs
  - id: data-api
    resource: https://openrouter.ai/docs/cookbook/administration/data-api
    title: OpenRouter Data API
  - id: server-tools
    resource: https://openrouter.ai/docs/guides/features/server-tools
    title: Server tools guide
---

# Scope

Every row is implemented and registered on `openrouter.Client`; method names are the public resource calls. `management` means a management API key is required by the endpoint documentation or SDK guidance. This replaces the duplicate inventories formerly in `APIs.md`.

# Inference and media

| Method | Path | Client call | Notes |
|---|---|---|---|
| POST | `/chat/completions` | `chat.completions.create`, `.stream` | Chat; stream is SSE. |
| POST | `/responses` | `responses.create`, `.stream` | Responses API; stream is SSE. |
| POST | `/messages` | `messages.create`, `.stream` | Anthropic-compatible; stream is SSE. |
| POST | `/embeddings` | `embeddings.create` | Text embeddings. |
| GET | `/embeddings/models` | `embeddings.models.list` | Embedding model discovery. |
| POST | `/rerank` | `rerank.create` | Document reranking. |
| POST | `/audio/speech` | `audio.speech.create` | Raw synthesized audio. |
| POST | `/audio/transcriptions` | `audio.transcriptions.create` | Base64 audio transcription. |
| POST | `/videos` | `videos.create` | Create a generation job. |
| GET | `/videos/{jobId}` | `videos.get` | Poll a job. |
| GET | `/videos/{jobId}/content` | `videos.content` | Download generated content. |
| GET | `/videos/models` | `videos.models.list` | Video model discovery. |
| POST | `/presets/{slug}/chat/completions` | `presets.chat.completions.create` | Preset chat inference. |
| POST | `/presets/{slug}/messages` | `presets.messages.create` | Preset Messages inference. |
| POST | `/presets/{slug}/responses` | `presets.responses.create` | Preset Responses inference. |

# Discovery and presets

| Method | Path | Client call | Notes |
|---|---|---|---|
| GET | `/models` | `models.list` | Available models. |
| GET | `/models/count` | `models.count` | Supports output-modality filtering. |
| GET | `/models/user` | `models.user.list` | Models available to the current user. |
| GET | `/model/{author}/{slug}` | `models.get` | A single model. |
| GET | `/models/{author}/{slug}/endpoints` | `models.endpoints.list` | A model's endpoints. |
| GET | `/endpoints/zdr` | `endpoints.zdr.list` | Zero-data-retention availability preview. |
| GET | `/tools` | `tools.list` | Beta management-key server-tool catalog, which may change; preserves `links.next` without pagination or default assumptions. |
| GET | `/tools/{name}` | `tools.get` | Beta management-key catalog detail, which may change and is distinct from inference request tool types. Aliases use the existing GET redirect behavior (up to 3 redirects); no manual redirect following. |
| GET | `/providers` | `providers.list` | Provider discovery. |
| GET | `/presets` | `presets.list` | Presets. |
| GET | `/presets/{slug}` | `presets.get` | One preset. |
| GET | `/presets/{slug}/versions` | `presets.versions.list` | Preset versions. |
| GET | `/presets/{slug}/versions/{version}` | `presets.versions.get` | One preset version. |

# Usage, datasets, and analytics

| Method | Path | Client call | Notes |
|---|---|---|---|
| GET | `/credits` | `credits.get` | management |
| GET | `/generation` | `generation.get` | Generation metadata. |
| GET | `/generation/content` | `generation.content` | Stored generation content. |
| POST | `/generation/feedback` | `generation.feedback` | management; mutating feedback for an authenticated account's generation. Server validates request-length constraints; no documented deduplication or idempotency, so callers must not blindly retry ambiguous failures. |
| GET | `/activity` | `activity.get` | management |
| GET | `/datasets/rankings-daily` | `datasets.rankings_daily.get` | Daily model token totals. |
| GET | `/datasets/app-rankings` | `datasets.app_rankings.get` | App rankings. |
| GET | `/datasets/benchmarks/artificial-analysis` | `datasets.benchmarks.artificial_analysis.get` | Benchmark data. |
| GET | `/datasets/benchmarks/design-arena` | `datasets.benchmarks.design_arena.get` | Benchmark data. |
| GET | `/datasets/session-cost` | `datasets.session_cost.get` | Weekly aggregate session costs, without individual session rows or user IDs; available with any inference API key. Source: [OpenRouter Data API](https://openrouter.ai/docs/cookbook/administration/data-api), as of `meta.as_of`. Data CC BY 4.0; when republishing the dataset itself, append “Licensed under CC BY 4.0.” |
| GET | `/benchmarks` | `benchmarks.list` | Unified benchmark discovery. |
| GET | `/classifications/task` | `classifications.task.get` | Task-classification shares; Source: OpenRouter (openrouter.ai/rankings). |
| GET | `/analytics/meta` | `analytics.meta.get` | management |
| POST | `/analytics/query` | `analytics.query` | management |

# Keys, OAuth, and BYOK

| Method | Path | Client call | Notes |
|---|---|---|---|
| GET | `/key` | `key.get` | Current-key metadata. |
| GET/POST | `/keys` | `keys.list`, `.create` | Managed API keys. |
| GET/PATCH/DELETE | `/keys/{hash}` | `keys.get`, `.update`, `.delete` | Managed API key. |
| POST | `/auth/keys/code` | `oauth.createAuthCode` | OAuth authorization code. |
| POST | `/auth/keys` | `oauth.exchangeAuthCodeForAPIKey` | OAuth code exchange. |
| GET/POST | `/byok` | `byok.list`, `.create` | management; provider secrets are request-only. |
| GET/PATCH/DELETE | `/byok/{id}` | `byok.get`, `.update`, `.delete` | management |

# Guardrails, workspaces, and organization

| Method | Path | Client call | Notes |
|---|---|---|---|
| GET/POST | `/guardrails` | `guardrails.list`, `.create` | management |
| GET/PATCH/DELETE | `/guardrails/{id}` | `guardrails.get`, `.update`, `.delete` | management |
| GET | `/guardrails/assignments/keys` | `guardrails.listKeyAssignments` | management |
| GET | `/guardrails/assignments/members` | `guardrails.listMemberAssignments` | management |
| GET | `/guardrails/{id}/assignments/keys` | `guardrails.listGuardrailKeyAssignments` | management |
| POST | `/guardrails/{id}/assignments/keys` | `guardrails.bulkAssignKeys` | management |
| POST | `/guardrails/{id}/assignments/keys/remove` | `guardrails.bulkUnassignKeys` | management |
| GET | `/guardrails/{id}/assignments/members` | `guardrails.listGuardrailMemberAssignments` | management |
| POST | `/guardrails/{id}/assignments/members` | `guardrails.bulkAssignMembers` | management |
| POST | `/guardrails/{id}/assignments/members/remove` | `guardrails.bulkUnassignMembers` | management |
| GET/POST | `/workspaces` | `workspaces.list`, `.create` | management |
| GET/PATCH/DELETE | `/workspaces/{id}` | `workspaces.get`, `.update`, `.delete` | management |
| POST | `/workspaces/{id}/members/add` | `workspaces.bulkAddMembers` | management |
| POST | `/workspaces/{id}/members/remove` | `workspaces.bulkRemoveMembers` | management |
| GET | `/workspaces/{id}/budgets` | `workspaces.budgets.list` | management |
| GET | `/workspaces/{workspace_ref}/budgets/{interval}` | `workspaces.budgets.get` | management |
| GET | `/workspaces/{id}/members` | `workspaces.members.list` | management |
| PUT/DELETE | `/workspaces/{id}/budgets/{interval}` | `workspaces.budgets.upsert`, `.delete` | management |
| GET | `/organization/members` | `organization.members.list` | management |

# Files and observability

| Method | Path | Client call | Notes |
|---|---|---|---|
| GET/POST | `/files` | `files.list`, `.upload` | Upload uses multipart form data. |
| GET/DELETE | `/files/{file_id}` | `files.get`, `.delete` | File metadata or deletion. |
| GET | `/files/{file_id}/content` | `files.content` | Raw content. |
| GET/POST | `/observability/destinations` | `observability.destinations.list`, `.create` | management |
| GET/PATCH/DELETE | `/observability/destinations/{id}` | `observability.destinations.get`, `.update`, `.delete` | management |

The matrix represents **91 distinct method/path operations**: rows combining verbs are expanded for that count. It excludes the upstream-deprecated `POST /credits/coinbase`, which is intentionally not exported. For audited specification gaps and implementation priorities, see the [API audit and roadmap](roadmap.md); planned operations are not coverage claims.
