# Update Log

## 2026-10-18
* **Live management-profile verification**: Six of seven read-only management checks passed (credits, BYOK, guardrails, workspaces, observability destinations, and activity). Organization-member listing returned HTTP 404 because the endpoint is available only for organization accounts. The run reported eight passed tests including two offline policy checks, thirteen skipped tests, and one failed test. A direct read-only HTTP diagnostic confirmed the account restriction; no mutation or inference was performed.
* **Live free-profile verification**: Using a local API key and `openrouter/free`, all six selected live checks passed (model list/count, provider list, current key, buffered chat, streaming chat), together with two offline profile-policy checks. Fourteen checks outside this profile were skipped. No SDK failure was observed in this run; paid and management capabilities remain unverified. The local credential file is excluded from Git.
* **Integration testing**: Added manually selected free/management/paid profiles through exported environment variables, honest skip reporting, uncached integration execution, and free-request quota parsing.
* **Phase 3 completion (endpoint scope)**: Implemented the 35 remaining operations and added offline transport/stream tests. Coverage is 150 operations, including all 148 non-deprecated specification operations. Updated lifecycle and authentication guidance; live account access remains unverified.
* **Phase 3**: Added eight SCIM operations with typed requests/responses and offline transport tests. Coverage is 115 operations with 35 non-deprecated specification gaps. Phase 3 remains incomplete; live enterprise access is unverified.

## 2026-10-17
* **Phase 3**: Rechecked the upstream specification and recorded enterprise/specialized API access constraints. Added organization settings and private-endpoint reads; coverage is 107 operations with 43 non-deprecated specification gaps. Live entitlement checks remain outstanding.

## 2026-10-15
* **Verification**: Validated the bundle, local Markdown links, the 35-command example catalog, package path, examples build, and unit tests after moving the bundle to `docs/`.
* **Creation**: Created the openrouter-zig knowledge bundle; see [Getting started](getting-started.md).
