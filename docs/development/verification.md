---
type: Guide
title: Verification
description: Run repository formatting, unit-test, example-build, and opt-in integration-test checks.
tags: [development, verification, testing, zig]
generated: { by: openai/gpt-6.1-sol, at: 2026-10-15T22:44:12Z }
sources:
  - id: agent-rules
    resource: ../../AGENT.md
    title: Repository agent guidance
  - id: build
    resource: ../../build.zig
    title: Zig build steps
---

# Required local checks

For a normal code change, repository guidance requires formatting and unit tests:[^agent-rules]

```sh
zig fmt .
zig build test
```

Build the package with `zig build` and all runnable examples with `zig build examples` when those checks apply. The build script defines the `test`, `examples`, and opt-in `integration-test` steps.[^build]

# Integration tests

Run `zig build integration-test` to execute the integration test target. Without `OPENROUTER_API_KEY`, integration tests skip network work; some tests additionally need `OPENROUTER_GENERATION_ID` or `OPENROUTER_MANAGEMENT_API_KEY`.[^agent-rules]

Keep credentials in local environment variables only. See [release process](release-process.md) for release-specific checks.

[^agent-rules]: Repository agent guidance.
[^build]: Zig build steps.
