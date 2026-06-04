const std = @import("std");
const openrouter = @import("openrouter");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const api_key = init.minimal.environ.getAlloc(allocator, "OPENROUTER_API_KEY") catch return error.MissingApiKey;
    defer allocator.free(api_key);
    const generation_id = init.minimal.environ.getAlloc(allocator, "OPENROUTER_GENERATION_ID") catch return error.MissingGenerationId;
    defer allocator.free(generation_id);

    var client = try openrouter.Client.init(allocator, init.io, .{
        .api_key = api_key,
    });
    defer client.deinit();

    var response = try client.generation.get(.{ .id = generation_id }, .{});
    defer response.deinit();

    std.debug.print("generation: {s}\nmodel: {s}\ncost: {d}\nusage: {d}\n", .{
        response.data.id,
        response.data.model,
        response.data.total_cost,
        response.data.usage,
    });
}
