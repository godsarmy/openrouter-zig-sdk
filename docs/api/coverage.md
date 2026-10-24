---
type: API Reference
title: OpenRouter Zig endpoint coverage
description: Canonical categorized inventory of the 150 HTTP endpoint operations exported by the client.
tags: [api, endpoints, coverage]
generated: { by: openai/gpt-5.6-terra, at: 2026-10-17T00:00:00Z }
sources:
  - resource: ../../src/containers.zig
    title: Container files
  - resource: ../../src/interns.zig
    title: Intern lifecycle and chat
  - resource: ../../src/vault.zig
    title: Workspace and intern secrets
  - resource: ../../src/oauth.zig
    title: OAuth infrastructure
  - resource: ../../src/decisions.zig
    title: System One and alpha Decisions
  - resource: ../../src/scim.zig
    title: SCIM directory management
  - resource: ../../src/organization.zig
    title: Organization settings and members
  - resource: ../../src/private_endpoints.zig
    title: Private endpoint lifecycle
  - id: client
    resource: ../../src/client.zig
    title: Client resource registration
  - id: batches
    resource: ../../src/batches.zig
    title: Batch API
  - id: end-users
    resource: ../../src/end_users.zig
    title: End-user management API
  - id: images
    resource: ../../src/images.zig
    title: Buffered image generation API
  - id: openrouter-api
    resource: https://openrouter.ai/openapi.json
    title: OpenRouter OpenAPI specification
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

Every row is implemented and registered on `openrouter.Client`; method names are the public resource calls. `management` means a management API key is required by the endpoint documentation or SDK guidance. This replaces the duplicate inventories formerly in `APIs.md`. SDK coverage does not grant account access: see [organization requirements and feature entitlements](account-access.md).

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
| POST | `/images` | `images.create` | Buffered JSON image generation; requests force `stream: false`. |
| GET | `/images/models` | `images.models.list` | Image model discovery. |
| GET | `/images/models/{author}/{slug}/endpoints` | `images.models.endpoints.list` | Image model endpoint capabilities. |
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

# Batches and end users

| Method | Path | Client call | Notes |
|---|---|---|---|
| GET/POST | `/batches` | `batches.list`, `.create` | Batch creation queues with `202`; request bodies are raw JSON objects, not file uploads. |
| GET/DELETE | `/batches/{id}` | `batches.get`, `.delete` | Delete is terminal-result deletion, not cancellation; do not blindly retry ambiguous mutations. |
| GET/POST | `/external-users` | `end_users.list`, `.create` | management; public SDK naming is retained; create returns `201`. |
| GET/PATCH/DELETE | `/external-users/{user}` | `end_users.get`, `.update`, `.delete` | management; delete is soft deactivation and returns `204`, not an inference access restriction. |

Batch creation supports `/v1/chat/completions`, `/v1/responses`, `/v1/messages`, and `/v1/embeddings`, with optional `completion_window`, `provider.only`, `provider.allow_fallbacks`, and `callback_url`. Batch-level fields serialize before `requests`, as required by OpenRouter's streaming request parser. Request bodies and result response bodies remain raw `std.json.Value` objects. See the [Batch API quickstart](https://openrouter.ai/docs/batch-quickstart).

Batch usage requires the three token counts; omitted optional cost and usage-detail fields default to null, matching the [official response schema](https://openrouter.ai/docs/api/api-reference/batch/get-a-batch). Other required batch and result fields remain required: abbreviated quickstart examples are not complete response fixtures.

Polling, webhook receiving/signature verification, and deduplication are caller responsibilities; setting `callback_url` does not install a receiver. Save results before deleting a terminal batch. The SDK has no batch cancellation operation.

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
| GET | `/organization/settings` | `organization.settings.get` | organization account and management key |
| PATCH | `/organization/settings` | `organization.settings.update` | organization account and management key; controls authenticated model-catalog filtering. |
| GET | `/private-endpoints` | `private_endpoints.list` | organization management key plus private-endpoint entitlement; includes drafts. |
| GET | `/private-endpoints/{id}` | `private_endpoints.get` | organization management key plus private-endpoint entitlement; upstream configuration and decimal-string pricing. |
| GET | `/organization/members` | `organization.members.list` | organization account and management key |

# SCIM directory management

Requires a management key and enabled SCIM access. Account availability is unverified; the tested personal account returned 404. Organization membership alone is not verified to enable SCIM. See [account access](account-access.md).

| Method | Path | Client call | Notes |
|---|---|---|---|
| GET | `/scim/groups` | `scim.listGroups` | management; pagination and exact name/external-ID filters. |
| GET/POST | `/scim/group-mappings` | `scim.listMappings`, `.createMapping` | management; same-role creation re-applies membership, different role conflicts. |
| GET/PATCH/DELETE | `/scim/group-mappings/{id}` | `scim.getMapping`, `.updateMapping`, `.deleteMapping` | management; deletion requires an explicit `keep_members` boolean. |
| POST | `/scim/sync-jobs` | `scim.createSyncJob` | management; queues work with HTTP 202, no request body. |
| GET | `/scim/sync-jobs/{id}` | `scim.getSyncJob` | management; caller polls status by job ID. |

# Files and observability

| Method | Path | Client call | Notes |
|---|---|---|---|
| GET/POST | `/files` | `files.list`, `.upload` | Upload uses multipart form data. |
| GET/DELETE | `/files/{file_id}` | `files.get`, `.delete` | File metadata or deletion. |
| GET | `/files/{file_id}/content` | `files.content` | Raw content. |
| GET/POST | `/observability/destinations` | `observability.destinations.list`, `.create` | management |
| GET/PATCH/DELETE | `/observability/destinations/{id}` | `observability.destinations.get`, `.update`, `.delete` | management |

# Enterprise and specialized operations

| Method | Path | Client call | Notes |
|---|---|---|---|
| POST | `/private-endpoints` | `private_endpoints.create` | management and entitlement; preserves partial-failure draft data. |
| PATCH/DELETE | `/private-endpoints/{id}` | `private_endpoints.update`, `.delete` | management and entitlement. |
| POST | `/private-endpoints/{id}/activate` | `private_endpoints.activate` | management and entitlement; validate first. |
| POST | `/private-endpoints/{id}/disable` | `private_endpoints.disable` | management and entitlement. |
| POST | `/private-endpoints/{id}/enable` | `private_endpoints.enable` | management and entitlement. |
| POST | `/private-endpoints/{id}/validate` | `private_endpoints.validate` | management and entitlement; explicit workspace. |
| PUT | `/private-endpoints/{id}/pricing` | `private_endpoints.updatePricing` | management and entitlement; decimal strings. |
| GET | `/containers/{container_id}/files` | `containers.listFiles` | Resume using last_id, including empty pages. |
| GET | `/containers/{container_id}/files/{file_id}` | `containers.getFile` | File metadata. |
| GET | `/containers/{container_id}/files/{file_id}/content` | `containers.content` | Buffered raw binary. |
| POST | `/containers/{container_id}/files/{file_id}/promote` | `containers.promoteFile` | Durable Files copy; consumes quota. |
| GET/POST | `/interns` | `interns.list`, `.create` | Intern API access; scoped to workspace. |
| GET/PATCH/DELETE | `/interns/{internId}` | `interns.get`, `.update`, `.delete` | Nullable updates; deletion accepted asynchronously. |
| POST | `/interns/{internId}/chat/completions` | `interns.chat` | SSE or 202 steering; preserves final session/usage chunk. |
| GET | `/interns/{internId}/daemon` | `interns.getDaemon` | Returns a sensitive daemon credential. |
| POST | `/interns/{internId}/daemon/sign` | `interns.signDaemon` | Personal OAuth grant with vault:read; API keys are refused. |
| POST | `/interns/{internId}/invoke` | `interns.invoke` | Asynchronous run or steering; HTTP 202. |
| POST | `/interns/{internId}/provision` | `interns.provision` | No body; HTTP 202. |
| POST | `/interns/{internId}/suspend` | `interns.suspendIntern` | No body. |
| GET | `/vault/secrets` | `vault.listSecrets` | Intern API access; workspace secret metadata. |
| PUT/DELETE | `/vault/secrets/{name}` | `vault.putSecret`, `.deleteSecret` | Workspace scope; deletion returns 204. |
| GET | `/vault/interns/{internId}/secrets` | `vault.listInternSecrets` | Secret metadata only. |
| GET | `/vault/interns/{internId}/effective-secrets` | `vault.listEffectiveSecrets` | Resolved metadata, including origin scope. |
| PUT/DELETE | `/vault/interns/{internId}/secrets/{name}` | `vault.putInternSecret`, `.deleteInternSecret` | Intern scope; deletion returns 204. |
| POST | `/vault/interns/{internId}/secrets/copy` | `vault.copySecrets` | Atomic workspace-to-intern copy. |
| GET | `/oauth/jwks` | `oauth.jwks` | Public signing keys; no bearer header. |
| POST | `/oauth/token` | `oauth.exchangeToken` | RFC 8693 form body; no client API-key header. |
| POST | `/systemone` | `systemone.create` | Typed questions/answers and application-defined state. |
| POST | `/api/alpha/decisions` | `alpha.decisions.create` | Special alpha base; shared System One types. |

The matrix represents **150 distinct method/path operations**: rows combining verbs are expanded for that count. It excludes `POST /credits/coinbase` and the two intern daemon-access aliases, which were deprecated in the earlier audit. This is an implementation inventory, not a claim of complete current specification coverage: the latest review identified a missing Vault connections read and specification drift affecting retained intern and benchmark routes. Absence from the specification does not establish server-side removal. See the [API audit and roadmap](roadmap.md); planned operations are not coverage claims.
