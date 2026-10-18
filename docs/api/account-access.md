---
type: Reference
title: Account access and organization features
description: Distinguish normal API keys, management keys, organization accounts, and feature entitlements.
tags: [api, authentication, organizations, access]
sources:
  - resource: ../development/integration-testing.md
    title: Observed live account coverage
  - resource: ../log.md
    title: Live verification results
  - resource: coverage.md
    title: Implemented endpoints
---

# Account access

An endpoint being implemented in this SDK does not mean every OpenRouter account can use it. The credential type, organization scope, and any feature entitlement all matter. A personal account can have a working management key without access to organization-only APIs.

| Feature | SDK calls checked | Access requirement and observed behavior |
|---|---|---|
| Organization members | `organization.members.list` | Organization account and management key. A personal-account test returned HTTP 404: `This endpoint is only available for organization accounts`. |
| Organization settings | `organization.settings.get` | Organization account and management key. A personal-account test returned the same organization-only HTTP 404. Settings updates were not tested live. |
| Private endpoints | `private_endpoints.list` | Organization management key and private-endpoint entitlement. The tested personal management key returned HTTP 403: `Private endpoints require an organization management key`. Lifecycle mutations were not tested live. |
| SCIM directory management | `scim.listGroups`, `scim.listMappings` | Management key and enabled SCIM access. Both reads returned HTTP 404 `Not found` for the tested account. The response did not establish the precise access requirement; creating an organization alone is not verified to enable SCIM. Confirm availability with OpenRouter. |

These observations come from the live checks recorded on 2026-10-18. An organization management key must belong to the organization whose data you intend to access. Additional keys for a personal account do not turn it into an organization account or enable restricted features.

Management operations are not all organization-only. The same tested management key successfully read its own identity, API-key listings, credits, BYOK, guardrails, workspaces, observability destinations, and activity. Free-model inference uses a normal API key and does not require an organization account for the tested paths.

# Interpreting access failures

The SDK currently maps these non-success HTTP responses to `error.ApiError`. That error alone does not prove an SDK defect or an invalid key. Check the endpoint's account requirements and the server's response before changing request or parsing code. A 404 can reflect an account restriction, as the organization-only responses above demonstrate; do not assume every 404 has that meaning.

Keep restricted capabilities marked as unverified until a successful request is made with the required account access. The integration suite leaves these failures visible rather than counting unavailable features as passed.

# Verify organization access

Use an organization-scoped management key in your local environment, then run the read-only profile:

```sh
export OPENROUTER_MANAGEMENT_API_KEY="<your-organization-management-key>"
export OPENROUTER_TEST_PROFILE=management
zig build integration-test
```

To check one API family:

```sh
zig build integration-test -Dintegration-filter="organization"
zig build integration-test -Dintegration-filter="SCIM"
zig build integration-test -Dintegration-filter="private endpoint"
```

See [manual integration testing](../development/integration-testing.md) for the full profile behavior and coverage limits. No account or resource mutations are required by these read-only checks.
