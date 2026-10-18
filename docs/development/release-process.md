---
type: Playbook
title: Release process
description: Prepare, verify, tag, and publish an openrouter-zig release.
tags: [development, release, verification]
generated: { by: openai/gpt-6.1-sol, at: 2026-10-15T22:44:12Z }
sources:
  - id: agent-rules
    resource: ../../AGENT.md
    title: Repository agent guidance
---

# Prepare

1. Update `src/version.zig`, `build.zig.zon`, `CHANGELOG.md`, and the README install tag.
2. For `1.0.0` and later, review public root exports in `src/openrouter.zig`; treat public API changes as breaking changes.[^agent-rules]

# Verify

```sh
zig fmt --check src/*.zig tests/*.zig examples/*.zig build.zig
zig build test
zig build examples
zig build integration-test
```

Without credentials, the integration command verifies skip paths and offline profile policy only. For release confidence, run credentialed integration checks with `OPENROUTER_API_KEY`; use `OPENROUTER_FUSION_TEST=1` and `OPENROUTER_FUSION_STRICT=1` when Fusion access is available, and `OPENROUTER_MANAGEMENT_API_KEY` if management endpoint behavior changed.[^agent-rules]

For a manually selected live run, export `OPENROUTER_TEST_PROFILE=free` and `OPENROUTER_API_KEY`, then run `zig build integration-test`. Select `management` or `paid` when appropriate. See [manual integration testing](integration-testing.md) for environment variables and coverage limits. Record which profiles actually ran in the release notes.

# Publish

Commit release preparation, create and push tag `vX.Y.Z`, then create the GitHub release. Never commit credentials or log authorization headers.[^agent-rules]

[^agent-rules]: Repository agent guidance.
