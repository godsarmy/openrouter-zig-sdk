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

    var response = try client.presets.chat.completions.create(.{
        .slug = "email-copywriter",
        .request = .{
            .model = "openai/gpt-4o-mini",
            .messages = &.{
                .{ .role = .user, .content = .{ .text = "Write a marketing email." } },
            },
            .temperature = 0.7,
        },
    }, .{});
    defer response.deinit();

    std.debug.print("preset {s}: {s}\n", .{ response.data.slug, response.data.id });
}
