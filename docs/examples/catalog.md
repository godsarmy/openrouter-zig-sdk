---
type: Example Catalog
title: Runnable example catalog
description: Complete mapping of the 36 build.zig run steps to their purpose and authentication requirement.
tags: [examples, build, authentication]
generated: { by: openai/gpt-6.1-sol, at: 2026-10-15T22:45:26Z }
sources:
  - id: build
    resource: ../../build.zig
    title: Example step registration
---

# Running examples

Build all examples with `zig build examples`. The commands below make network requests when run. **API key** means `OPENROUTER_API_KEY`; **management key** means `OPENROUTER_MANAGEMENT_API_KEY`; **generation ID** means `OPENROUTER_GENERATION_ID` is also needed.

| Command | Source | Purpose | Authentication |
|---|---|---|---|
| `run-async-chat` | `async_chat.zig` | Concurrent chat clients | API key |
| `run-oauth-keys` | `oauth_keys.zig` | PKCE authorization-code flow | API key + callback URL |
| `run-chat` | `chat.zig` | Basic chat completion | API key |
| `run-fusion` | `fusion.zig` | Fusion plugin | API key |
| `run-server-tools` | `server_tools.zig` | Typed server tools | API key |
| `run-stream` | `stream.zig` | Streaming chat completion | API key |
| `run-list-models` | `list_models.zig` | List models | API key |
| `run-list-user-models` | `list_user_models.zig` | List user models | API key |
| `run-list-model-endpoints` | `list_model_endpoints.zig` | Model endpoint discovery | API key |
| `run-endpoints-zdr` | `endpoints_zdr.zig` | ZDR endpoint preview | API key |
| `run-files` | `files.zig` | File lifecycle | API key |
| `run-models-count` | `models_count.zig` | Count/filter models | API key |
| `run-videos` | `videos.zig` | Create and poll video jobs | API key |
| `run-video-models` | `video_models.zig` | List video models | API key |
| `run-preset-chat-completions` | `preset_chat_completions.zig` | Preset chat completion | API key |
| `run-rerank` | `rerank.zig` | Rerank documents | API key |
| `run-audio-speech` | `audio_speech.zig` | Text-to-speech | API key |
| `run-audio-transcriptions` | `audio_transcriptions.zig` | Audio transcription | API key |
| `run-responses` | `responses.zig` | Responses API | API key |
| `run-responses-stream` | `responses_stream.zig` | Streaming Responses API | API key |
| `run-messages` | `messages.zig` | Messages API | API key |
| `run-messages-stream` | `messages_stream.zig` | Streaming Messages API | API key |
| `run-embeddings` | `embeddings.zig` | Create embeddings | API key |
| `run-embeddings-models` | `embeddings_models.zig` | List embedding models | API key |
| `run-byok` | `byok.zig` | BYOK credential management | management key |
| `run-guardrails` | `guardrails.zig` | Guardrail management | management key |
| `run-workspaces` | `workspaces.zig` | Workspace and budget management | management key |
| `run-observability-destinations` | `observability_destinations.zig` | Observability destination management | management key |
| `run-organization-members` | `organization_members.zig` | List organization members | management key |
| `run-credits` | `credits.zig` | Credits and usage | management key |
| `run-providers` | `providers.zig` | List providers | API key |
| `run-generation` | `generation.zig` | Generation metadata | API key + generation ID |
| `run-generation-content` | `generation_content.zig` | Stored generation content | API key + generation ID |
| `run-activity` | `activity.zig` | Account activity | management key |
| `run-analytics` | `analytics.zig` | Analytics query | management key |
| `run-rankings-daily` | `rankings_daily.zig` | Daily rankings dataset | API key |
