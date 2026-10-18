const std = @import("std");
const openrouter = @import("openrouter");
const support = @import("support.zig");

test "responses streaming integration" {
    try support.requireProfile(.chat);
    var threaded: std.Io.Threaded = .init_single_threaded;
    defer threaded.deinit();
    var client = try support.initPublicClient(&threaded);
    defer client.deinit();

    const model = try support.protocolModel("OPENROUTER_RESPONSES_MODEL", "openai/gpt-4o-mini");
    try support.prepareChat(&client, threaded.io());
    var stream = try client.responses.stream(.{
        .model = model,
        .input = .{ .text = "Reply with only: ok" },
        .max_output_tokens = 64,
    }, .{});
    defer stream.deinit();

    var events_seen: usize = 0;
    var saw_text = false;
    var saw_success = false;
    while (events_seen < 256) {
        var event = (try stream.next()) orelse break;
        defer event.deinit();
        events_seen += 1;
        if (event.textDelta()) |text| saw_text = saw_text or text.len > 0;
        if (event.reasoningDelta()) |text| saw_text = saw_text or text.len > 0;
        if (event.isTerminal()) {
            const limited = if (event.type) |kind| std.mem.eql(u8, kind, "response.incomplete") and support.tokenLimitedResponse(event.response) else false;
            if (!event.isSuccess() and !limited) return error.ResponseFailed;
            saw_success = true;
            break;
        }
    }
    if (!saw_success) return error.StreamLimitExceeded;
    try std.testing.expect(events_seen > 0);
    try std.testing.expect(saw_text);
}

test "responses buffered integration" {
    try support.requireProfile(.chat);
    var threaded: std.Io.Threaded = .init_single_threaded;
    defer threaded.deinit();
    var client = try support.initPublicClient(&threaded);
    defer client.deinit();
    const model = try support.protocolModel("OPENROUTER_RESPONSES_MODEL", "openai/gpt-4o-mini");
    try support.prepareChat(&client, threaded.io());
    var response = try client.responses.create(.{
        .model = model,
        .input = .{ .text = "Reply with only: ok" },
        .max_output_tokens = 64,
    }, .{});
    defer response.deinit();
    try std.testing.expect(response.id != null and response.id.?.len > 0);
    try std.testing.expect(response.output != null and response.output.?.len > 0);
    const status = response.status orelse return error.MissingResponseStatus;
    try std.testing.expect(std.mem.eql(u8, status, "completed") or std.mem.eql(u8, status, "incomplete"));
}
