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

    var response = try client.audio.speech.create(.{
        .model = "elevenlabs/eleven-turbo-v2",
        .input = "Hello from OpenRouter Zig.",
        .voice = "alloy",
        .response_format = .pcm,
    }, .{});
    defer response.deinit();

    std.debug.print("received {d} audio bytes\n", .{response.data().len});
}
