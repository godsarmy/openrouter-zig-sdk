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

    var response = try client.videos.create(.{
        .model = "google/veo-3.1",
        .prompt = "A serene mountain landscape at sunset",
        .aspect_ratio = "16:9",
        .duration = 8,
        .resolution = "720p",
    }, .{});
    defer response.deinit();

    std.debug.print("video job {s}: {s}\n", .{ response.id, @tagName(response.status) });
}
