---
type: Reference
title: API audit and implementation roadmap
description: Specification audit baseline, implementation priorities, and fidelity caveats.
tags: [api, roadmap, coverage]
generated: { by: openai/gpt-5.6-terra, at: 2026-10-17T00:00:00Z }
sources:
  - resource: ../../src/organization.zig
    title: Organization settings and members
  - resource: ../../src/private_endpoints.zig
    title: Private endpoint reads
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
  - resource: ../../src/batches.zig
    title: Batch API
  - resource: ../../src/end_users.zig
    title: End-user management API
  - resource: ../../src/images.zig
    title: Buffered image generation API
  - resource: https://openrouter.ai/openapi.json
    title: OpenRouter OpenAPI specification
  - resource: https://openrouter.ai/docs/api/api-reference/chat/create-a-chat-completion
    title: Chat completion API reference
  - resource: https://openrouter.ai/docs/api_reference/streaming
    title: Streaming API reference
  - resource: https://openrouter.ai/docs/guides/routing/provider-selection
    title: Provider selection guide
  - resource: https://openrouter.ai/docs/cookbook/administration/data-api
    title: OpenRouter Data API
  - resource: https://openrouter.ai/docs/guides/features/server-tools
    title: Server tools guide
---

# API audit and implementation roadmap

This is a planning document, not an endpoint-coverage claim. The historical audit was retrieved on 2026-10-15 from the [official OpenAPI specification](https://openrouter.ai/openapi.json) and the [API reference overview](https://openrouter.ai/docs/api_reference/overview). It found 151 method/path operations, including 3 deprecated operations, or **148 non-deprecated operations**. At that time, of the canonical [150 implemented operations](coverage.md), **148 overlapped with the specification**, leaving **zero non-deprecated endpoint gaps**. These are historical counts, not current coverage claims. This comparison normalizes path-parameter names and does not establish when any API was introduced.

Two implemented operations, `GET /datasets/benchmarks/artificial-analysis` and `GET /datasets/benchmarks/design-arena`, are absent from the retrieved OpenAPI. Their absence does not establish server-side removal or deprecation; verify their current support before changing the client. All Phase 3 operations are included in these counts. The specification was retrieved again on 2026-10-18 and still contains 151 operations, including 3 deprecated operations. The Phase 3 inventory was rechecked; this is not a fresh field-parity audit of existing implementations. The gap calculation therefore uses the 148-operation intersection, not direct subtraction of all 150 implemented operations.

Paths below are normally relative to `https://openrouter.ai/api/v1`. `/api/alpha/decisions` is a special alpha path. The client derives it by replacing the configured trailing `/v1` with `/alpha`, preserving proxy prefixes, as in the [official OpenRouter AI SDK](https://github.com/OpenRouterTeam/ai-sdk-provider). Other custom base URL layouts return `InvalidBaseUrl` for this operation.

### Subsequent compatibility review

The current specification documents `/external-users` rather than `/end-users`; the SDK now uses the documented routes while retaining `client.end_users` and existing public type names. No live management mutations were used to verify old-route support. The review also identified `GET /vault/interns/{internId}/connections` as a follow-up endpoint gap. Retained intern lifecycle and benchmark operations are absent from the reviewed specification; do not infer server removal from that absence.

Buffered Responses now retain `error`/`incomplete_details`, and embeddings accept an omitted response `index`. Expanded embeddings request options remain follow-up work. The review was targeted, not an exhaustive field-parity audit.

## Priorities

### Phase 1 — inference fidelity and routing

1. **Done: Responses streaming** uses the shared SSE infrastructure with typed common event fields, raw event preservation, text/reasoning helpers, function-call argument separation, and terminal-state handling. Typed full request/input/output expansion remains follow-up work. Review the [basic Responses usage](https://openrouter.ai/docs/api_reference/responses/basic-usage) and [Responses tool calling](https://openrouter.ai/docs/api_reference/responses/tool-calling) documentation.
2. **Done: Chat response and streaming fidelity** adds typed response tool calls, reasoning details, nested citations, refusal, generated images, and additive typed content parts while retaining legacy string `content`. Streaming deltas expose indexed tool-call fragments without accumulation helpers and preserve raw message/delta values. Generated audio remains raw JSON. This expands existing `POST /chat/completions` representations only; endpoint coverage remains unchanged. Review the [chat completion reference](https://openrouter.ai/docs/api/api-reference/chat/create-a-chat-completion), [reasoning guide](https://openrouter.ai/docs/guides/best-practices/reasoning-tokens), and [streaming reference](https://openrouter.ai/docs/api_reference/streaming).
3. **Done: Chat provider routing** adds typed privacy, hard-filter, quantization, sort, soft throughput/latency preference, and maximum-price fields, plus scoped `provider.options`. Existing routing helpers remain compatible; other endpoint provider fields remain raw JSON. This expands the existing chat completion request only, so endpoint coverage is unchanged. See the [provider-selection guide](https://openrouter.ai/docs/guides/routing/provider-selection) and [chat completion reference](https://openrouter.ai/docs/api/api-reference/chat/create-a-chat-completion).

Do not promise `store` or `previous_response_id` for Responses until the documentation/schema conflict is resolved: the Responses documentation rejects them while the schema lists them. Prefer `reasoning` over deprecated `include_reasoning`.

### Phase 2 — broad supported product surface

**Done (endpoint scope):** images, batches, tools, end users, generation feedback, and the planned discovery, data, and workspace reads. Images are buffered only: `images.create` forces `stream: false`; image SSE remains a follow-up. Batch request and result bodies deliberately remain raw JSON because they are endpoint-polymorphic. Image capability maps also remain raw JSON. Phase 2 completion does not promise full field parity for these APIs.

```zig
var image = try client.images.create(.{ .model = "provider/model", .prompt = "A sunset" }, .{});
defer image.deinit();
var batch = try client.batches.create(request, .{}); // queued: HTTP 202
defer batch.deinit();
```

End-user lifecycle endpoints require a management API key; `end_users.create` returns `201` and `end_users.delete` soft-deactivates with `204`. Registration state does not block inference. Batch deletion removes terminal batches and is not cancellation. Image model GET endpoints are anonymous per the specification, but the SDK's existing client credential policy is unchanged. No live mutations were used for verification.

### Phase 3 — enterprise and specialized APIs

**Done (endpoint scope):** all 35 remaining operations are implemented alongside organization settings, SCIM, and private-endpoint reads. The client now exports private-endpoint mutations, container files, interns (including chat SSE and daemon signing), Vault, OAuth infrastructure, System One, and alpha Decisions. Requests and responses are typed, with owned data/metadata and offline tests. This is endpoint coverage, not a promise of exhaustive field parity or verified account access.

| Group | Access and lifecycle behavior | Status |
|---|---|---|
| Organization settings | Management key; controls authenticated model discovery. | Implemented. |
| Private endpoints | Management key and entitlement. Creation makes a draft; validation and activation are separate. Create-with-activate may fail after creating a draft. `CreateResponse.failure` and `.status` report HTTP failure while `.endpoint` and `.validation` preserve recovery data. Pass `Idempotency-Key` through request options. Draft edits invalidate validation; active edits may return 409. | All 10 operations implemented. |
| SCIM | Management key. Same-role mapping creation re-applies membership; different roles conflict. Sync creation requires explicit polling. | All 8 operations implemented. |
| Containers | Use `last_id` as the next `after`, including empty scan-boundary pages. Content is buffered binary. Promotion copies into durable Files storage and consumes quota. | All 4 operations implemented. |
| Interns | Explicit workspace on creation; regional hosts are refused by the service. Provision/suspend send no body. Chat returns SSE or a 202 steering response; final empty-choice SSE events preserve session ID and usage. Daemon signing requires a personal OAuth grant with `vault:read`, supplied as the client bearer credential. | All 11 non-deprecated operations implemented. |
| Vault | API-key workspace selects scope; no fallback. Reads return metadata only, including nullable legacy host bindings. Writes may return 503 when disabled. Copy is atomic and may reject legacy hostless secrets. | All 8 operations implemented. |
| OAuth infrastructure | JWKS is public. RFC 8693 token exchange uses form encoding and the workload identity JWT, without sending the client API key. Separate from API-key authorization-code exchange. | Both operations implemented. |
| System One | Typed question variants and answers; application-defined state, guidance, and trace remain JSON. The service maps bare model IDs to `typesafe/`. | Implemented. |
| Alpha Decisions | Uses `/api/alpha/decisions`, preserving the configured API prefix. Shares typed questions/answers with System One. Alpha shapes may change. | Implemented. |

Live enterprise entitlement, rollout gates, OAuth federation, and alpha account access have not been verified. Verification used no live mutations. Endpoint coverage does not imply that every caller is entitled to these APIs.

## Verification per phase

- Add serialization and parsing tests.
- Exercise SSE events, errors, and unknown event types.
- Preserve compatibility with existing public types and calls.
- Run `zig fmt --check`, `zig build`, `zig build test`, and `zig build examples`.
- Use opt-in integration tests only with configured credentials.
- Update [endpoint coverage](coverage.md) only when an operation is implemented, and repeat this specification-drift comparison for future audits.

## Current non-deprecated gap inventory

No endpoint gaps remain against the specification retrieved on 2026-10-18 (148 non-deprecated operations). Future specification changes and field-level fidelity remain separate follow-up work.

## Deprecated exclusions

Continue to exclude `POST /credits/coinbase`. Do not add deprecated `GET /interns/{internId}/daemon-access` or `POST /interns/{internId}/daemon-access/sign`; use the daemon replacements listed above instead.
