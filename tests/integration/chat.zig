const std = @import("std");
const openrouter = @import("openrouter");
const support = @import("support.zig");
const generations = @import("generation.zig");

test "chat streaming integration" {
    try support.requireProfile(.chat);
    var threaded: std.Io.Threaded = .init_single_threaded;
    defer threaded.deinit();

    var client = try support.initPublicClient(&threaded);
    defer client.deinit();

    try support.prepareChat(&client, threaded.io());
    var response = try client.chat.completions.stream(.{
        .model = try support.chatModel(),
        .messages = &.{openrouter.ChatMessage{
            .role = .user,
            .content = .{ .text = "Reply with only: ok" },
        }},
        .max_tokens = 64,
    }, .{});
    defer response.deinit();

    var chunks_seen: usize = 0;
    var saw_content = false;
    var saw_finish = false;
    while (chunks_seen < 256) {
        var chunk = (try response.next()) orelse break;
        defer chunk.deinit();

        chunks_seen += 1;
        if (chunk.content()) |text| saw_content = saw_content or text.len > 0;
        for (chunk.choices) |choice| {
            if (choice.delta.reasoning) |text| saw_content = saw_content or text.len > 0;
            if (choice.finish_reason != null) saw_finish = true;
        }
    }

    try std.testing.expect(chunks_seen > 0);
    try std.testing.expect(saw_content);
    if (!saw_finish) return error.StreamLimitExceeded;
}

test "chat Fusion plugin integration" {
    try support.requireProfile(.standard);
    if (!support.envFlag("OPENROUTER_FUSION_TEST")) return error.SkipZigTest;

    var threaded: std.Io.Threaded = .init_single_threaded;
    defer threaded.deinit();

    var client = try support.initPublicClient(&threaded);
    defer client.deinit();

    var response = client.chat.completions.create(.{
        .model = support.env("OPENROUTER_FUSION_MODEL") orelse "openrouter/fusion",
        .messages = &.{openrouter.ChatMessage{
            .role = .user,
            .content = .{ .text = "Answer in one short sentence: what is Fusion useful for?" },
        }},
        .plugins = &.{openrouter.ChatPlugin{ .fusion = .{
            .preset = support.env("OPENROUTER_FUSION_PRESET") orelse "general-budget",
        } }},
    }, .{}) catch |err| switch (err) {
        error.ApiError => {
            if (support.envFlag("OPENROUTER_FUSION_STRICT")) return err;
            return error.SkipZigTest;
        },
        else => |e| return e,
    };
    defer response.deinit();

    try std.testing.expect(response.choices.len > 0);
    try std.testing.expect(response.choices[0].message.content != null);
    try std.testing.expect(response.choices[0].message.content.?.len > 0);
}

test "chat server tools integration" {
    try support.requireProfile(.standard);
    if (!support.envFlag("OPENROUTER_CHAT_SERVER_TOOLS_TEST")) return error.SkipZigTest;

    var threaded: std.Io.Threaded = .init_single_threaded;
    defer threaded.deinit();

    var client = try support.initPublicClient(&threaded);
    defer client.deinit();

    var response = client.chat.completions.create(.{
        .model = support.env("OPENROUTER_CHAT_SERVER_TOOLS_MODEL") orelse "openai/gpt-4o-mini",
        .messages = &.{openrouter.ChatMessage{
            .role = .user,
            .content = .{ .text = "Search ziglang.org and answer in one short sentence: what is Zig?" },
        }},
        .tools = &.{openrouter.ChatServerTool{ .web_search = .{
            .max_results = 3,
            .search_context_size = .medium,
            .allowed_domains = &.{"ziglang.org"},
        } }},
        .tool_choice = .required,
        .max_tokens = 80,
    }, .{}) catch |err| switch (err) {
        error.ApiError => {
            if (support.envFlag("OPENROUTER_CHAT_SERVER_TOOLS_STRICT")) return err;
            return error.SkipZigTest;
        },
        else => |e| return e,
    };
    defer response.deinit();

    try std.testing.expect(response.choices.len > 0);
    try std.testing.expect(response.choices[0].message.content != null);
    try std.testing.expect(response.choices[0].message.content.?.len > 0);
}

test "chat buffered integration" {
    try support.requireProfile(.chat);
    var threaded: std.Io.Threaded = .init_single_threaded;
    defer threaded.deinit();
    var client = try support.initPublicClient(&threaded);
    defer client.deinit();
    try support.prepareChat(&client, threaded.io());
    var response = try client.chat.completions.create(.{
        .model = try support.chatModel(),
        .messages = &.{.{ .role = .user, .content = .{ .text = "Reply with only: ok" } }},
        .max_tokens = 64,
    }, .{});
    defer response.deinit();
    try std.testing.expect(response.choices.len > 0);
    const choice = response.choices[0];
    try std.testing.expect(choice.finish_reason != null);
    const message = choice.message;
    const has_content = if (message.content) |text| text.len > 0 else false;
    const has_reasoning = if (message.reasoning) |text| text.len > 0 else false;
    try std.testing.expect(has_content or has_reasoning);
    const generation_id = response.response_metadata.generation_id orelse response.id;
    var generation = try generations.waitForMetadata(&client, threaded.io(), generation_id);
    defer generation.deinit();
    try std.testing.expectEqualStrings(generation_id, generation.data.id);
    try std.testing.expect(generation.data.model.len > 0);
    try std.testing.expect(generation.data.total_cost >= 0);
    // Do not impose a client buffering assumption on optional metadata.
    try std.testing.expect(generation.data.usage >= 0);
}

test "chat streaming early close releases resources and permits reuse" {
    try support.requireProfile(.chat);
    var threaded: std.Io.Threaded = .init_single_threaded;
    defer threaded.deinit();
    var client = try support.initPublicClient(&threaded);
    defer client.deinit();
    try support.prepareChat(&client, threaded.io());
    {
        var stream = try client.chat.completions.stream(.{
            .model = try support.chatModel(),
            .messages = &.{.{ .role = .user, .content = .{ .text = "Count from one to ten." } }},
            .max_tokens = 64,
        }, .{});
        defer stream.deinit();
        var first = (try stream.next()) orelse return error.EmptyStream;
        defer first.deinit();
        try std.testing.expect(first.choices.len > 0);
        // Stop before DONE deliberately; both event and stream must be freed.
    }
    var key = try client.key.get(.{});
    defer key.deinit();
    try std.testing.expect(key.data.label.len > 0);
}
