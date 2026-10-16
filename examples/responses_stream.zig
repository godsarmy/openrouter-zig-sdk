const std = @import("std");
const openrouter = @import("openrouter");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const api_key = init.minimal.environ.getAlloc(allocator, "OPENROUTER_API_KEY") catch return error.MissingApiKey;
    defer allocator.free(api_key);

    var client = try openrouter.Client.init(allocator, init.io, .{ .api_key = api_key });
    defer client.deinit();

    var stream = try client.responses.stream(.{
        .model = "openai/gpt-4o-mini",
        .input = .{ .text = "Write one short sentence about Zig." },
    }, .{});
    defer stream.deinit();

    while (try stream.next()) |event| {
        var owned_event = event;
        defer owned_event.deinit();
        if (owned_event.textDelta()) |text| std.debug.print("{s}", .{text});
        if (owned_event.isTerminal() and !owned_event.isSuccess()) return error.ResponseFailed;
    }
    std.debug.print("\n", .{});
}
