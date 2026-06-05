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

    var response = try client.datasets.rankings_daily.get(.{}, .{});
    defer response.deinit();

    std.debug.print("Source: OpenRouter (openrouter.ai/rankings), as of {s}.\n", .{response.meta.as_of});
    for (response.data) |item| {
        std.debug.print("{s} {s} tokens={s}\n", .{
            item.date,
            item.model_permaslug,
            item.total_tokens,
        });
    }
}
