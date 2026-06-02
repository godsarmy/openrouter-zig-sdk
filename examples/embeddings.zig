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

    var response = try client.embeddings.create(.{
        .model = "openai/text-embedding-3-small",
        .input = .{ .string = "Hello from Zig." },
    }, .{});
    defer response.deinit();

    std.debug.print("model: {s}\n", .{response.model});
    std.debug.print("vectors: {d}\n", .{response.data.len});
    if (response.data.len > 0) {
        std.debug.print("dimensions: {d}\n", .{response.data[0].embedding.len});
    }
}
