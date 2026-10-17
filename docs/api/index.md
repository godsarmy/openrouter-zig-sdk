# API Reference

* [Endpoint coverage](coverage.md) - Canonical, categorized matrix of every SDK HTTP endpoint.
* [API audit and roadmap](roadmap.md) - Current specification gaps, priorities, and implementation caveats.

The base URL is `https://openrouter.ai/api/v1`. Paths in the matrix are relative to it.

Organization settings and private-endpoint reads require a management API key; private endpoints also require an entitlement. Returned values own their data and must be deinitialized:

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
