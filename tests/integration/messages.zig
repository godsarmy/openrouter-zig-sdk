const std = @import("std");
const openrouter = @import("openrouter");
const support = @import("support.zig");

test "messages streaming integration" {
    try support.requireProfile(.chat);
    var threaded: std.Io.Threaded = .init_single_threaded;
    defer threaded.deinit();

    var client = try support.initPublicClient(&threaded);
    defer client.deinit();

    const model = try support.protocolModel("OPENROUTER_MESSAGES_MODEL", "anthropic/claude-3.5-haiku");
    try support.prepareChat(&client, threaded.io());
    var response = try client.messages.stream(.{
        .model = model,
        .messages = &.{.{
            .role = .user,
            .content = .{ .text = "Reply with only: ok" },
        }},
        .max_tokens = 64,
    }, .{});
    defer response.deinit();

    var events_seen: usize = 0;
    var saw_content = false;
    var saw_stop = false;
    while (events_seen < 256) {
        var event = (try response.next()) orelse break;
        defer event.deinit();

        events_seen += 1;
        if (event.error_value != null) return error.ResponseFailed;
        if (event.type) |kind| {
            if (std.mem.eql(u8, kind, "message_stop")) saw_stop = true;
        }
        try std.testing.expect(event.type != null or event.message != null or event.delta != null);
        if (event.message != null) saw_content = true;
        if (event.textDelta()) |text| saw_content = saw_content or text.len > 0;
    }

    try std.testing.expect(events_seen > 0);
    try std.testing.expect(saw_content);
    if (!saw_stop) return error.StreamLimitExceeded;
}

test "messages buffered integration" {
    try support.requireProfile(.chat);
    var threaded: std.Io.Threaded = .init_single_threaded;
    defer threaded.deinit();
    var client = try support.initPublicClient(&threaded);
    defer client.deinit();
    const model = try support.protocolModel("OPENROUTER_MESSAGES_MODEL", "anthropic/claude-3.5-haiku");
    try support.prepareChat(&client, threaded.io());
    var response = try client.messages.create(.{
        .model = model,
        .messages = &.{.{ .role = .user, .content = .{ .text = "Reply with only: ok" } }},
        .max_tokens = 64,
    }, .{});
    defer response.deinit();
    try std.testing.expect(response.id != null and response.id.?.len > 0);
    try std.testing.expect(response.role == .assistant);
    try std.testing.expect(response.content != null and response.content.?.len > 0);
    try std.testing.expect(response.stop_reason != null);
}
