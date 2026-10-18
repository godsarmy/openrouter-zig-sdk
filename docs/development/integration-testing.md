---
type: Guide
title: Manual integration testing
description: Run explicit free, management, or paid profiles using exported environment variables.
tags: [development, testing, integration]
sources:
  - resource: ../../tests/integration.zig
    title: Live SDK checks and profile policy
  - resource: ../../build.zig
    title: Integration execution step
  - resource: ../../src/key.zig
    title: Current-key quota parsing
  - resource: https://openrouter.ai/docs/api_reference/limits
    title: OpenRouter limits
  - resource: https://openrouter.ai/openrouter/free
    title: Free model router
---

# Run free-model tests manually

Export a normal OpenRouter API key and explicitly select the free profile:

```sh
export OPENROUTER_API_KEY="<your-api-key>"
export OPENROUTER_TEST_PROFILE=free
unset OPENROUTER_CHAT_MODEL
zig build integration-test
```

Keep credentials in your local environment; do not commit them or put real keys in shared terminal transcripts. To enter a key without including its value in Bash history, use `read -rs -p 'OpenRouter API key: ' OPENROUTER_API_KEY` followed by `export OPENROUTER_API_KEY` instead of a literal export.

The free profile defaults to `openrouter/free`. To pin a current free model, export `OPENROUTER_CHAT_MODEL="vendor/model:free"`. The free profile rejects paid model IDs and does not switch to paid inference. An inherited paid chat model will fail validation instead of silently being used.

It runs model/tool catalog reads, current-key reads, buffered and streaming checks for Chat, Messages, and Responses, and early chat-stream termination. The seven inference requests are each capped at 64 output tokens. The buffered chat check also retrieves metadata for the exact generation with at most four metadata reads and 2/4/8-second persistence waits; inference is never repeated. Before each chat request, it reads the key's free-request quota if supplied by the server and fails when none remains. It waits 3.5 seconds before inference and configures a single attempt. Tests check response structure and non-empty text or reasoning, rather than exact generated wording.

The free router may choose different models between runs. Pin a current `:free` model when comparing SDK changes. Quota checks do not reserve capacity against other processes using your account. Additional keys do not increase account limits; consult the [current OpenRouter limits](https://openrouter.ai/docs/api_reference/limits).

# Other profiles

| `OPENROUTER_TEST_PROFILE` | Credential variable | Live checks |
|---|---|---|
| `free` | `OPENROUTER_API_KEY` | Model catalog/count/details/endpoints, provider/tool discovery, current key, buffered/streaming Chat, Messages, and Responses, generation metadata, and early chat-stream cleanup. |
| `management` | `OPENROUTER_MANAGEMENT_API_KEY` | Current management-key identity, API-key listing, credits, BYOK, guardrails, workspaces, observability, organization members/settings, SCIM groups/mappings, private endpoints, and activity. No inference or mutations. |
| `paid` | `OPENROUTER_API_KEY` | Standard discovery, current key, buffered/streaming Chat, Messages, and Responses, generation metadata, and early chat-stream cleanup. No management calls. Can spend credits. |

Management checks use a separate management key:

```sh
export OPENROUTER_MANAGEMENT_API_KEY="<your-management-key>"
export OPENROUTER_TEST_PROFILE=management
zig build integration-test
```

To opt into paid inference:

```sh
export OPENROUTER_TEST_PROFILE=paid
unset OPENROUTER_CHAT_MODEL
zig build integration-test
```

In the free profile, Messages and Responses use the same free model as chat unless their protocol-specific model variables select another free model. Paid chat defaults to `openai/gpt-4o-mini`; Messages and Responses use their existing model defaults. Override them with `OPENROUTER_CHAT_MODEL`, `OPENROUTER_MESSAGES_MODEL`, and `OPENROUTER_RESPONSES_MODEL` respectively. In the paid profile, Fusion and server-tool tests require `OPENROUTER_FUSION_TEST=1` or `OPENROUTER_CHAT_SERVER_TOOLS_TEST=1`. Generation reads require `OPENROUTER_GENERATION_ID`. Those optional tests remain excluded from the free profile even when their flags are inherited.

Organization-member listing and organization settings require an organization account. SCIM and private-endpoint reads also depend on account features or entitlements. A management key for a personal account can return HTTP 404 for this endpoint while the other management reads work; this test remains a failure so missing account coverage is visible.

The selected profile determines which credential variable is used. The free and paid profiles ignore the management credential; the management profile ignores the normal credential. When finished, remove credentials from the session with `unset OPENROUTER_API_KEY OPENROUTER_MANAGEMENT_API_KEY`.

# Interpret results

Missing credentials and profile exclusions appear as **skipped**, rather than successful live checks. Offline profile and terminal-state policy tests can pass even when all live tests skip. CI unsets both credential variables and performs no live requests.

The integration execution step bypasses Zig's result cache. Compilation can still be cached, but each explicit invocation executes tests again, even when only the environment or remote availability changed.

Without `OPENROUTER_TEST_PROFILE`, the command retains its broader legacy scope for compatibility. Supplying credentials in that mode can run tests with paid defaults, so select `free` explicitly when you want free inference. An unrecognized profile fails.

A failed API request remains a failure. Optional Fusion/server-tool API refusals are reported as skipped unless their respective strict flag is set. The SDK's generic `ApiError` does not currently distinguish every credential, quota, entitlement, and provider refusal at this level; investigate those separately before treating a live failure as an SDK regression.

These checks do not validate every Phase 3 endpoint, enterprise mutation, or model capability. A management key does not grant missing account entitlements. Record the profiles that actually ran when assessing release confidence.

# Suite layout

`tests/integration.zig` is a small entry point. API checks live under `tests/integration/` in `discovery.zig`, `chat.zig`, `messages.zig`, `responses.zig`, `generation.zig`, and `management.zig`. `support.zig` contains shared credential/profile policy, pacing, and client initialization. The command remains `zig build integration-test`.

Messages streaming must reach `message_stop`; Responses streaming must reach a valid terminal event. A documented `max_output_tokens` incomplete response is accepted as a valid bounded result; other unsuccessful terminal states fail. Early stream termination deliberately deinitializes before `[DONE]` and then reuses the client for a read-only key request.

To investigate one endpoint without repeating the entire live suite, filter test names:

```sh
zig build integration-test -Dintegration-filter="tool catalog discovery"
zig build integration-test -Dintegration-filter="chat buffered integration"
```

Tool detail lookups use the catalog entry's canonical `id`, not its display `name`. Generation lookup prefers response metadata's generation ID when present; its optional `streamed` metadata is not required to match the SDK buffering mode.

# Observed account coverage

The workspace-key verification exercised all thirteen free-profile cases across full and targeted runs. The generation metadata check exposed an SDK parsing issue with omitted provider-attempt fields; an offline regression and a targeted live rerun passed after the fix.

The management credential passed eight read-only checks. Organization members/settings returned HTTP 404 with an organization-account requirement; SCIM groups/mappings returned HTTP 404 `Not found`; private endpoints returned HTTP 403 requiring an organization management key. These five capabilities are not verified and remain visible as failures for this account. They are not evidence that the other management checks or the free inference key are invalid.
