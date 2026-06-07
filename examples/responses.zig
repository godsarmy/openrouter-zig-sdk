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

    var response = try client.responses.create(.{
        .model = "openai/o4-mini",
        .input = .{ .text = "Write one sentence about Zig." },
        .max_output_tokens = 128,
    }, .{});
    defer response.deinit();

    std.debug.print("response id: {s}\n", .{response.id orelse "<none>"});
    std.debug.print("output items: {d}\n", .{if (response.output) |items| items.len else 0});
}
