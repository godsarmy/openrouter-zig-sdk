---
type: Guide
title: Retries and errors
description: Configure bounded retries and inspect OpenRouter API failures.
tags: [client, retry, errors, http]
generated: { by: openai/gpt-6.1-sol, at: 2026-10-15T22:44:12Z }
sources:
  - id: retry
    resource: ../../src/retry.zig
    title: Retry policy implementation
  - id: errors
    resource: ../../src/errors.zig
    title: API error implementation
  - id: config
    resource: ../../src/config.zig
    title: Client configuration definition
---

# Retry policy

The default `RetryConfig` makes up to three attempts, starts at 500 ms, caps delays at 60 seconds, and uses a 1.5 multiplier. It retries connection errors, HTTP 429, and HTTP 500, 502, 503, 524, and 529 by default.[^retry]

When a retryable response has an integer `Retry-After` value, the delay uses that number of seconds, capped by `max_delay_ms`; otherwise it uses exponential delay.[^retry]

```zig
var client = try openrouter.Client.init(allocator, io, .{
    .api_key = api_key,
    .retry = .{
        .max_attempts = 2,
        .retry_429 = false,
    },
});
defer client.deinit();
```

# API failures

HTTP/API failures use `error.ApiError`. `ApiError` retains its status, optional code and request ID, message, and raw response body; call `api_error.deinit()` when finished. `kind()` classifies common statuses and `retryable()` identifies the retryable status set.[^errors]

Do not put API keys or authorization headers in diagnostic output. Configuration and initialization details are in [configuration](configuration.md).

[^retry]: Retry policy implementation.
[^errors]: API error implementation.
