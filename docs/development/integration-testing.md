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

It runs catalog/key reads and two small chat requests (buffered and streaming), each capped at 64 output tokens. Before each chat request, it reads the key's free-request quota if supplied by the server and fails when none remains. It waits 3.5 seconds before inference and configures a single attempt. Tests check response structure and non-empty text or reasoning, rather than exact generated wording.

The free router may choose different models between runs. Pin a current `:free` model when comparing SDK changes. Quota checks do not reserve capacity against other processes using your account. Additional keys do not increase account limits; consult the [current OpenRouter limits](https://openrouter.ai/docs/api_reference/limits).

# Other profiles

| `OPENROUTER_TEST_PROFILE` | Credential variable | Live checks |
|---|---|---|
| `free` | `OPENROUTER_API_KEY` | Model catalog/count, provider catalog, current key, buffered chat, and streaming chat. |
| `management` | `OPENROUTER_MANAGEMENT_API_KEY` | Credits, BYOK, guardrails, workspaces, observability destinations, organization members, and activity reads. No inference or mutations. |
| `paid` | `OPENROUTER_API_KEY` | Standard discovery, current key, buffered/streaming chat, Messages streaming, and Responses streaming. No management calls. Can spend credits. |

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

Paid chat defaults to `openai/gpt-4o-mini`; Messages and Responses use their existing model defaults. Override them with `OPENROUTER_CHAT_MODEL`, `OPENROUTER_MESSAGES_MODEL`, and `OPENROUTER_RESPONSES_MODEL` respectively. In the paid profile, Fusion and server-tool tests require `OPENROUTER_FUSION_TEST=1` or `OPENROUTER_CHAT_SERVER_TOOLS_TEST=1`. Generation reads require `OPENROUTER_GENERATION_ID`. Those optional tests remain excluded from the free profile even when their flags are inherited.

Organization-member listing additionally requires an organization account. A management key for a personal account can return HTTP 404 for this endpoint while the other management reads work; this test remains a failure so missing account coverage is visible.

The selected profile determines which credential variable is used. The free and paid profiles ignore the management credential; the management profile ignores the normal credential. When finished, remove credentials from the session with `unset OPENROUTER_API_KEY OPENROUTER_MANAGEMENT_API_KEY`.

# Interpret results

Missing credentials and profile exclusions appear as **skipped**, rather than successful live checks. Two offline profile-policy tests can pass even when all live tests skip. CI unsets both credential variables and performs no live requests.

The integration execution step bypasses Zig's result cache. Compilation can still be cached, but each explicit invocation executes tests again, even when only the environment or remote availability changed.

Without `OPENROUTER_TEST_PROFILE`, the command retains its broader legacy scope for compatibility. Supplying credentials in that mode can run tests with paid defaults, so select `free` explicitly when you want free inference. An unrecognized profile fails.

A failed API request remains a failure. Optional Fusion/server-tool API refusals are reported as skipped unless their respective strict flag is set. The SDK's generic `ApiError` does not currently distinguish every credential, quota, entitlement, and provider refusal at this level; investigate those separately before treating a live failure as an SDK regression.

These checks do not validate every Phase 3 endpoint, enterprise mutation, or model capability. A management key does not grant missing account entitlements. Record the profiles that actually ran when assessing release confidence.
