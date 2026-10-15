---
type: Guide
title: Client configuration
description: Configure credentials, endpoint, attribution headers, timeout, and retries for a client.
tags: [client, configuration, retry]
generated: { by: openai/gpt-6.1-sol, at: 2026-10-15T22:44:12Z }
sources:
  - id: config
    resource: ../../src/config.zig
    title: Client configuration definition
  - id: client
    resource: ../../src/client.zig
    title: Client initialization and URL validation
---

# Configuration fields

`Config.api_key` is required and must not be empty. `Client.init` accepts only HTTP or HTTPS base URLs with a host and no fragment.[^client]

| Field | Default | Purpose |
|---|---|---|
| `api_key` | required | OpenRouter bearer credential |
| `base_url` | `https://openrouter.ai/api/v1` | API base URL |
| `http_referer` | `null` | Optional `HTTP-Referer` attribution header |
| `x_title` | `null` | Optional `X-Title` attribution header |
| `timeout_ms` | `60_000` | Request timeout setting |
| `retry` | `.{}` | Default retry policy |

```zig
var client = try openrouter.Client.init(allocator, io, .{
    .api_key = api_key,
    .http_referer = "https://your-site.example",
    .x_title = "Your App",
    .retry = .{ .max_attempts = 4 },
});
defer client.deinit();
```

Endpoint calls take `RequestOptions`; see [retries and errors](retries-and-errors.md) for retry behavior. Keep credentials out of source code and logs.

[^config]: Client configuration definition.
[^client]: Client initialization and URL validation.
