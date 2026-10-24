# API Reference

* [Account access](account-access.md) - Organization-only APIs, management keys, and feature entitlements.
* [Endpoint coverage](coverage.md) - Canonical, categorized matrix of every SDK HTTP endpoint.
* [API audit and roadmap](roadmap.md) - Current specification gaps, priorities, and implementation caveats.

The base URL is `https://openrouter.ai/api/v1`. Paths in the matrix are relative to it, except alpha Decisions, which replaces the trailing `/v1` with `/alpha`.

Messages requests use `MessagesSpeed` values `.fast` and `.standard`; numeric `speed` values are no longer accepted by the typed API. Leaving `speed` null omits it in both buffered and streaming requests. The existing `client.end_users` resource now targets the documented `/external-users` routes; its public resource and type names are unchanged.

Chat `ToolCall` retains its `id`, `name`, and `arguments` construction API but serializes the required nested `function` wire format. Request messages accept `reasoning_details` from response messages; keep the source response alive until the next request has been serialized. For structured output, set `response_format.type = .json_schema` and provide `response_format.json_schema` (`ChatJsonSchemaConfig`) with a name and JSON Schema object, plus optional `strict` and `description`. Missing configuration or a non-object schema fails serialization with `error.WriteFailed`; `.text` and `.json_object` formats remain unchanged.

Buffered Responses expose `error` and `incomplete_details` as optional raw JSON values, owned until response `deinit`. Inspect them alongside `status` for failed or incomplete generations; they do not replace HTTP error handling. Embedding items expose `index: ?u32`: an omitted index is null, not an inferred position or zero. Handle null explicitly when matching vectors to inputs.

Organization settings require an organization account and management key; private endpoints require an organization management key and entitlement. A personal management key does not unlock these APIs. See [account access](account-access.md) for live observations and SCIM access limitations. Returned values own their data and must be deinitialized:

```zig
var settings = try client.organization.settings.get(.{});
defer settings.deinit();
var endpoints = try client.private_endpoints.list(.{});
defer endpoints.deinit();
// To change authenticated model discovery:
// var updated = try client.organization.settings.update(.{
//     .is_filtered_model_catalog_enabled = false,
// }, .{});
// defer updated.deinit();
```

Private-endpoint lifecycle states and declared regions preserve future string values. Pricing remains decimal strings; list responses include drafts and expose summaries, while `get(id, options)` returns upstream configuration.

SCIM calls require a management key and own their responses. For example:

```zig
var groups = try client.scim.listGroups(.{ .display_name = "Engineering" }, .{});
defer groups.deinit();
var job = try client.scim.createSyncJob(.{});
defer job.deinit();
var status = try client.scim.getSyncJob(job.data.id, .{});
defer status.deinit();
```

Poll sync jobs explicitly until `succeeded` or `failed`; unknown status values are preserved. Mapping deletion takes `.{ .keep_members = true }` to retain workspace membership, or `false` to remove memberships granted by the mapping. Recreating an existing mapping with the same role re-applies it; a different role returns an API error. Live account access has not been verified.

The originally planned Phase 3 endpoints are implemented; this is not a claim of complete coverage of the evolving specification (see the [roadmap](roadmap.md)). Container, intern, Vault, and Decisions types are exported under `openrouter.containers`, `.interns`, `.vault`, and `.decisions`. Their owned JSON responses expose the decoded payload as `.value`; deinitialize every returned response. Container content exposes raw bytes with `.data()`.

```zig
var files = try client.containers.listFiles("container-id", .{}, .{});
defer files.deinit();
// Use files.value.last_id as the next request's after, even if data is empty.
var secrets = try client.vault.listSecrets(.{ .limit = 20 }, .{});
defer secrets.deinit();
```

Private-endpoint creation returns an owned result even on an HTTP error: inspect `.failure` and `.status`, then recover `.endpoint` and `.validation` if a draft was created. Set an `Idempotency-Key` in request options when retrying creation. Validation takes a workspace ID; activation is a separate call. Update declarations use `.clear` for JSON null or `.{ .value = false }` / `.{ .value = "us" }` to set a value. Pricing updates take `.{ .pricing = .{ .prompt = "0.0000025", .completion = "0.00001" } }`.

Intern creation requires an explicit workspace ID. Update fields support `.clear` to send JSON null, or `.{ .value = "..." }` to set a string; omitted fields stay unchanged. `interns.provision` and `interns.suspendIntern` send no body. `interns.delete` defaults `acknowledge_workspace_loss` to false. Daemon signing requires a personal OAuth bearer with `vault:read`, supplied in the client credential; a management API key does not substitute for it.

`oauth.jwks` fetches public signing keys without validating a JWT. `oauth.exchangeToken` performs RFC 8693 workload identity exchange with form encoding and omits the client API key. It returns an owned short-lived access token. These APIs are separate from `oauth.createAuthCode` and `oauth.exchangeAuthCodeForAPIKey`.

`systemone.create` and `alpha.decisions.create` share `openrouter.decisions.Request`: application-defined JSON state, a map of typed `noul`, `choice`, `score`, or `box` questions, and typed answers. The alpha call requires a configured base ending in `/v1`, preserving proxy prefixes. The service maps bare System One model IDs into `typesafe/`. Entitlements, rollout gates, and live account access remain unverified; see the [roadmap](roadmap.md).
