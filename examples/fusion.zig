const std = @import("std");
const openrouter = @import("openrouter");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const api_key = init.minimal.environ.getAlloc(allocator, "OPENROUTER_API_KEY") catch null orelse {
        std.debug.print("Set OPENROUTER_API_KEY to run this example.\n", .{});
        return;
    };
    defer allocator.free(api_key);

    var client = try openrouter.Client.init(allocator, init.io, .{
        .api_key = api_key,
    });
    defer client.deinit();

    var response = try client.chat.completions.create(.{
        .model = "openrouter/fusion",
        .messages = &.{openrouter.ChatMessage{
            .role = .user,
            .content = .{ .text = "Compare ridge, lasso, and elastic-net regression in three bullet points." },
        }},
        .plugins = &.{openrouter.ChatPlugin{ .fusion = .{
            .preset = "general-budget",
        } }},
    }, .{});
    defer response.deinit();

    std.debug.print("{s}\n", .{response.choices[0].message.content.?});
}
