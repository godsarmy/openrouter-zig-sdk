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

    var response = try client.rerank.create(.{
        .model = "cohere/rerank-v3.5",
        .query = "What is the capital of France?",
        .documents = &.{
            "Paris is the capital of France.",
            "Berlin is the capital of Germany.",
        },
        .top_n = 1,
    }, .{});
    defer response.deinit();

    for (response.results) |result| {
        std.debug.print("{d}: {s}\n", .{ result.index, result.document.text });
    }
}
