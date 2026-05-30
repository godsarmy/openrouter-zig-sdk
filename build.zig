const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const openrouter = b.addModule("openrouter", .{
        .root_source_file = b.path("src/openrouter.zig"),
        .target = target,
    });

    const examples_step = b.step("examples", "Build examples");
    addExample(b, examples_step, target, optimize, openrouter, "chat", "examples/chat.zig");
    addExample(b, examples_step, target, optimize, openrouter, "stream", "examples/stream.zig");
    addExample(b, examples_step, target, optimize, openrouter, "list_models", "examples/list_models.zig");

    const tests = b.addTest(.{
        .root_module = openrouter,
    });
    const run_tests = b.addRunArtifact(tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);
}

fn addExample(
    b: *std.Build,
    examples_step: *std.Build.Step,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    openrouter: *std.Build.Module,
    name: []const u8,
    path: []const u8,
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
}
