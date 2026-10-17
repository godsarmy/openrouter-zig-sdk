---
type: Reference
title: API audit and implementation roadmap
description: Specification audit baseline, implementation priorities, and fidelity caveats.
tags: [api, roadmap, coverage]
generated: { by: openai/gpt-6.1-sol, at: 2026-10-17T00:00:00Z }
sources:
  - resource: ../../src/workspaces.zig
    title: Workspace management API
  - resource: ../../src/benchmarks.zig
    title: Unified benchmarks API
  - resource: ../../src/classifications.zig
    title: Task classifications API
  - resource: ../../src/chat.zig
    title: Chat completion response types and parser
  - resource: ../../src/stream.zig
    title: Chat completion streaming parser
  - resource: https://openrouter.ai/docs/api/api-reference/chat/create-a-chat-completion
    title: Chat completion API reference
  - resource: https://openrouter.ai/docs/api_reference/streaming
    title: Streaming API reference
  - resource: https://openrouter.ai/docs/guides/routing/provider-selection
    title: Provider selection guide
---

# API audit and implementation roadmap

This is a planning document, not an endpoint-coverage claim. The audit was retrieved on 2026-10-15 from the [official OpenAPI specification](https://openrouter.ai/openapi.json) and the [API reference overview](https://openrouter.ai/docs/api_reference/overview). It found 151 method/path operations, including 3 deprecated operations, or **148 non-deprecated operations**. Of the canonical [87 implemented operations](coverage.md), **85 overlap with the current specification**, leaving **63 current specification gaps**. This comparison normalizes path-parameter names and does not establish when any API was introduced.

Two implemented operations, `GET /datasets/benchmarks/artificial-analysis` and `GET /datasets/benchmarks/design-arena`, are absent from the retrieved OpenAPI. Their absence does not establish server-side removal or deprecation; verify their current support before changing the client. `GET /benchmarks`, `GET /classifications/task`, `GET /workspaces/{id}/members`, and `GET /workspaces/{workspace_ref}/budgets/{interval}` were added since this historical audit; the current accounting reflects them but does not claim a fresh audit. The gap calculation therefore uses the 85-operation intersection, not direct subtraction of all 87 implemented operations.

Paths below are normally relative to `https://openrouter.ai/api/v1`. `/api/alpha/decisions` is recorded exactly as specified: it is a special path and must not be normalized blindly. Verify its base URL before implementation.

## Priorities

### Phase 1 — inference fidelity and routing

1. **Done: Responses streaming** uses the shared SSE infrastructure with typed common event fields, raw event preservation, text/reasoning helpers, function-call argument separation, and terminal-state handling. Typed full request/input/output expansion remains follow-up work. Review the [basic Responses usage](https://openrouter.ai/docs/api_reference/responses/basic-usage) and [Responses tool calling](https://openrouter.ai/docs/api_reference/responses/tool-calling) documentation.
2. **Done: Chat response and streaming fidelity** adds typed response tool calls, reasoning details, nested citations, refusal, generated images, and additive typed content parts while retaining legacy string `content`. Streaming deltas expose indexed tool-call fragments without accumulation helpers and preserve raw message/delta values. Generated audio remains raw JSON. This expands existing `POST /chat/completions` representations only; endpoint coverage remains unchanged. Review the [chat completion reference](https://openrouter.ai/docs/api/api-reference/chat/create-a-chat-completion), [reasoning guide](https://openrouter.ai/docs/guides/best-practices/reasoning-tokens), and [streaming reference](https://openrouter.ai/docs/api_reference/streaming).
3. **Done: Chat provider routing** adds typed privacy, hard-filter, quantization, sort, soft throughput/latency preference, and maximum-price fields, plus scoped `provider.options`. Existing routing helpers remain compatible; other endpoint provider fields remain raw JSON. This expands the existing chat completion request only, so endpoint coverage is unchanged. See the [provider-selection guide](https://openrouter.ai/docs/guides/routing/provider-selection) and [chat completion reference](https://openrouter.ai/docs/api/api-reference/chat/create-a-chat-completion).

Do not promise `store` or `previous_response_id` for Responses until the documentation/schema conflict is resolved: the Responses documentation rejects them while the schema lists them. Prefer `reasoning` over deprecated `include_reasoning`.

### Phase 2 — broad supported product surface

Implement images, batches, tools, end users, generation feedback, and missing discovery, data, and workspace reads. Prioritize stable, generally available APIs and share pagination, error, and request-option machinery where possible.

### Phase 3 — enterprise and specialized APIs

Evaluate private endpoints, SCIM, vault, interns, OAuth infrastructure, organization settings, containers, SystemOne, and alpha decisions. Check stability, entitlement/access requirements, and documentation completeness before committing to public SDK types. Alpha and enterprise API access must be verified.

## Verification per phase

- Add serialization and parsing tests.
- Exercise SSE events, errors, and unknown event types.
- Preserve compatibility with existing public types and calls.
- Run `zig fmt --check`, `zig build`, `zig build test`, and `zig build examples`.
- Use opt-in integration tests only with configured credentials.
- Update [endpoint coverage](coverage.md) only when an operation is implemented, and repeat this specification-drift comparison for future audits.

## Current non-deprecated gap inventory (63 operations)

The following confirmed audit baseline is verb-expanded: every listed verb/path pair is one operation.

| Method | Path | Phase / notes |
|---|---|---|
| POST | `/api/alpha/decisions` | P3; special alpha path; verify base and access. |
| GET | `/batches` | P2 |
| POST | `/batches` | P2 |
| GET | `/batches/{id}` | P2 |
| DELETE | `/batches/{id}` | P2 |
| GET | `/datasets/session-cost` | P2 data |
| GET | `/end-users` | P2 |
| POST | `/end-users` | P2 |
| GET | `/end-users/{user}` | P2 |
| PATCH | `/end-users/{user}` | P2 |
| DELETE | `/end-users/{user}` | P2 |
| POST | `/generation/feedback` | P2 |
| POST | `/images` | P2 |
| GET | `/images/models` | P2 |
| GET | `/images/models/{author}/{slug}/endpoints` | P2 |
| GET | `/containers/{container_id}/files` | P3 |
| GET | `/containers/{container_id}/files/{file_id}` | P3 |
| GET | `/containers/{container_id}/files/{file_id}/content` | P3 |
| POST | `/containers/{container_id}/files/{file_id}/promote` | P3 |
| GET | `/interns` | P3 |
| POST | `/interns` | P3 |
| GET | `/interns/{internId}` | P3 |
| PATCH | `/interns/{internId}` | P3 |
| DELETE | `/interns/{internId}` | P3 |
| POST | `/interns/{internId}/chat/completions` | P3 |
| GET | `/interns/{internId}/daemon` | P3; replacement daemon API. |
| POST | `/interns/{internId}/daemon/sign` | P3; replacement daemon API. |
| POST | `/interns/{internId}/invoke` | P3 |
| POST | `/interns/{internId}/provision` | P3 |
| POST | `/interns/{internId}/suspend` | P3 |
| GET | `/oauth/jwks` | P3 |
| POST | `/oauth/token` | P3 |
| GET | `/organization/settings` | P3 |
| PATCH | `/organization/settings` | P3 |
| GET | `/private-endpoints` | P3 |
| POST | `/private-endpoints` | P3 |
| GET | `/private-endpoints/{id}` | P3 |
| PATCH | `/private-endpoints/{id}` | P3 |
| DELETE | `/private-endpoints/{id}` | P3 |
| POST | `/private-endpoints/{id}/activate` | P3 |
| POST | `/private-endpoints/{id}/disable` | P3 |
| POST | `/private-endpoints/{id}/enable` | P3 |
| POST | `/private-endpoints/{id}/validate` | P3 |
| PUT | `/private-endpoints/{id}/pricing` | P3 |
| GET | `/scim/group-mappings` | P3 |
| POST | `/scim/group-mappings` | P3 |
| GET | `/scim/group-mappings/{id}` | P3 |
| PATCH | `/scim/group-mappings/{id}` | P3 |
| DELETE | `/scim/group-mappings/{id}` | P3 |
| GET | `/scim/groups` | P3 |
| POST | `/scim/sync-jobs` | P3 |
| GET | `/scim/sync-jobs/{id}` | P3 |
| GET | `/tools` | P2 |
| GET | `/tools/{name}` | P2 |
| POST | `/systemone` | P3 |
| GET | `/vault/secrets` | P3 |
| PUT | `/vault/secrets/{name}` | P3 |
| DELETE | `/vault/secrets/{name}` | P3 |
| GET | `/vault/interns/{internId}/effective-secrets` | P3 |
| GET | `/vault/interns/{internId}/secrets` | P3 |
| PUT | `/vault/interns/{internId}/secrets/{name}` | P3 |
| DELETE | `/vault/interns/{internId}/secrets/{name}` | P3 |
| POST | `/vault/interns/{internId}/secrets/copy` | P3 |


## Deprecated exclusions

Continue to exclude `POST /credits/coinbase`. Do not add deprecated `GET /interns/{internId}/daemon-access` or `POST /interns/{internId}/daemon-access/sign`; use the daemon replacements listed above instead.
