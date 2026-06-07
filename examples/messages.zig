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

    var response = try client.messages.create(.{
        .model = "anthropic/claude-sonnet-4",
        .messages = &.{.{
            .role = .user,
            .content = .{ .text = "Write one sentence about Zig." },
        }},
        .max_tokens = 128,
    }, .{});
    defer response.deinit();

    std.debug.print("message id: {s}\n", .{response.id orelse "<none>"});
    std.debug.print("content blocks: {d}\n", .{if (response.content) |items| items.len else 0});
}
