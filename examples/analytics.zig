const std = @import("std");
const openrouter = @import("openrouter");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const api_key = init.minimal.environ.getAlloc(allocator, "OPENROUTER_MANAGEMENT_API_KEY") catch return error.MissingApiKey;
    defer allocator.free(api_key);

    var client = try openrouter.Client.init(allocator, init.io, .{
        .api_key = api_key,
    });
    defer client.deinit();

    var meta = try client.analytics.meta.get(.{});
    defer meta.deinit();

    std.debug.print("available metrics: {d}\n", .{meta.data.metrics.len});
    if (meta.data.metrics.len > 0) {
        std.debug.print("first metric: {s}\n", .{meta.data.metrics[0].name});
    }

    var response = try client.analytics.query(.{
        .metrics = &.{"request_count"},
        .dimensions = &.{"model"},
        .granularity = "day",
        .limit = 10,
    }, .{});
    defer response.deinit();

    std.debug.print("rows: {d}, query_time_ms: {d}\n", .{
        response.data.metadata.row_count,
        response.data.metadata.query_time_ms,
    });
}
