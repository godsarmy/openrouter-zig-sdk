const std = @import("std");
const openrouter = @import("openrouter");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const api_key = init.minimal.environ.getAlloc(allocator, "OPENROUTER_API_KEY") catch return error.MissingApiKey;
    defer allocator.free(api_key);

    var client = try openrouter.Client.init(allocator, init.io, .{
        .api_key = api_key,
    });
    defer client.deinit();

    var response = try client.messages.stream(.{
        .model = "anthropic/claude-sonnet-4",
        .messages = &.{.{
            .role = .user,
            .content = .{ .text = "Write one short sentence about Zig." },
        }},
        .max_tokens = 128,
    }, .{});
    defer response.deinit();

    while (try response.next()) |event| {
        var owned_event = event;
        defer owned_event.deinit();

        if (owned_event.textDelta()) |text| {
            std.debug.print("{s}", .{text});
        }
    }
    std.debug.print("\n", .{});
}
