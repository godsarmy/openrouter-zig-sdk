const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const openrouter = b.addModule("openrouter", .{
        .root_source_file = b.path("src/openrouter.zig"),
        .target = target,
    });

    const examples_step = b.step("examples", "Build examples");
    addExample(b, examples_step, target, optimize, openrouter, "async_chat", "examples/async_chat.zig", "run-async-chat", "Run async chat example");
    addExample(b, examples_step, target, optimize, openrouter, "oauth_keys", "examples/oauth_keys.zig", "run-oauth-keys", "Run auth-key OAuth example");
    addExample(b, examples_step, target, optimize, openrouter, "chat", "examples/chat.zig", "run-chat", "Run chat example");
    addExample(b, examples_step, target, optimize, openrouter, "fusion", "examples/fusion.zig", "run-fusion", "Run Fusion plugin example");
    addExample(b, examples_step, target, optimize, openrouter, "server_tools", "examples/server_tools.zig", "run-server-tools", "Run server tools example");
    addExample(b, examples_step, target, optimize, openrouter, "stream", "examples/stream.zig", "run-stream", "Run stream example");
    addExample(b, examples_step, target, optimize, openrouter, "list_models", "examples/list_models.zig", "run-list-models", "Run list models example");
    addExample(b, examples_step, target, optimize, openrouter, "list_user_models", "examples/list_user_models.zig", "run-list-user-models", "Run list user models example");
    addExample(b, examples_step, target, optimize, openrouter, "list_model_endpoints", "examples/list_model_endpoints.zig", "run-list-model-endpoints", "Run list model endpoints example");
    addExample(b, examples_step, target, optimize, openrouter, "endpoints_zdr", "examples/endpoints_zdr.zig", "run-endpoints-zdr", "Run endpoints ZDR example");
    addExample(b, examples_step, target, optimize, openrouter, "files", "examples/files.zig", "run-files", "Run files example");
    addExample(b, examples_step, target, optimize, openrouter, "models_count", "examples/models_count.zig", "run-models-count", "Run models count example");
    addExample(b, examples_step, target, optimize, openrouter, "videos", "examples/videos.zig", "run-videos", "Run videos example");
    addExample(b, examples_step, target, optimize, openrouter, "video_models", "examples/video_models.zig", "run-video-models", "Run video models example");
    addExample(b, examples_step, target, optimize, openrouter, "preset_chat_completions", "examples/preset_chat_completions.zig", "run-preset-chat-completions", "Run preset chat completions example");
    addExample(b, examples_step, target, optimize, openrouter, "rerank", "examples/rerank.zig", "run-rerank", "Run rerank example");
    addExample(b, examples_step, target, optimize, openrouter, "audio_speech", "examples/audio_speech.zig", "run-audio-speech", "Run audio speech example");
    addExample(b, examples_step, target, optimize, openrouter, "audio_transcriptions", "examples/audio_transcriptions.zig", "run-audio-transcriptions", "Run audio transcriptions example");
    addExample(b, examples_step, target, optimize, openrouter, "responses", "examples/responses.zig", "run-responses", "Run responses example");
    addExample(b, examples_step, target, optimize, openrouter, "messages", "examples/messages.zig", "run-messages", "Run messages example");
    addExample(b, examples_step, target, optimize, openrouter, "messages_stream", "examples/messages_stream.zig", "run-messages-stream", "Run messages streaming example");
    addExample(b, examples_step, target, optimize, openrouter, "embeddings", "examples/embeddings.zig", "run-embeddings", "Run embeddings example");
    addExample(b, examples_step, target, optimize, openrouter, "embeddings_models", "examples/embeddings_models.zig", "run-embeddings-models", "Run embeddings models example");
    addExample(b, examples_step, target, optimize, openrouter, "byok", "examples/byok.zig", "run-byok", "Run BYOK example");
    addExample(b, examples_step, target, optimize, openrouter, "guardrails", "examples/guardrails.zig", "run-guardrails", "Run guardrails example");
    addExample(b, examples_step, target, optimize, openrouter, "workspaces", "examples/workspaces.zig", "run-workspaces", "Run workspaces example");
    addExample(b, examples_step, target, optimize, openrouter, "observability_destinations", "examples/observability_destinations.zig", "run-observability-destinations", "Run observability destinations example");
    addExample(b, examples_step, target, optimize, openrouter, "organization_members", "examples/organization_members.zig", "run-organization-members", "Run organization members example");
    addExample(b, examples_step, target, optimize, openrouter, "credits", "examples/credits.zig", "run-credits", "Run credits example");
    addExample(b, examples_step, target, optimize, openrouter, "providers", "examples/providers.zig", "run-providers", "Run providers example");
    addExample(b, examples_step, target, optimize, openrouter, "generation", "examples/generation.zig", "run-generation", "Run generation metadata example");
    addExample(b, examples_step, target, optimize, openrouter, "generation_content", "examples/generation_content.zig", "run-generation-content", "Run generation content example");
    addExample(b, examples_step, target, optimize, openrouter, "activity", "examples/activity.zig", "run-activity", "Run activity example");
    addExample(b, examples_step, target, optimize, openrouter, "analytics", "examples/analytics.zig", "run-analytics", "Run analytics example");
    addExample(b, examples_step, target, optimize, openrouter, "rankings_daily", "examples/rankings_daily.zig", "run-rankings-daily", "Run rankings daily example");

    const tests = b.addTest(.{
        .root_module = openrouter,
    });
    const run_tests = b.addRunArtifact(tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);

    const integration_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/integration.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .imports = &.{
                .{ .name = "openrouter", .module = openrouter },
            },
        }),
    });
    const run_integration_tests = b.addRunArtifact(integration_tests);

    const integration_test_step = b.step("integration-test", "Run opt-in integration tests");
    integration_test_step.dependOn(&run_integration_tests.step);
}

fn addExample(
    b: *std.Build,
    examples_step: *std.Build.Step,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    openrouter: *std.Build.Module,
    name: []const u8,
    path: []const u8,
    run_step_name: []const u8,
    run_step_description: []const u8,
) void {
    const exe = b.addExecutable(.{
        .name = name,
        .root_module = b.createModule(.{
            .root_source_file = b.path(path),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "openrouter", .module = openrouter },
            },
        }),
    });

    examples_step.dependOn(&exe.step);

    const run_step = b.step(run_step_name, run_step_description);
    const run_cmd = b.addRunArtifact(exe);
    if (b.args) |args| run_cmd.addArgs(args);
    run_step.dependOn(&run_cmd.step);
}
