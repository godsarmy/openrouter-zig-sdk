const std = @import("std");
const openrouter = @import("openrouter");
const support = @import("support.zig");

test "list models integration" {
    try support.requireProfile(.discovery);
    var threaded: std.Io.Threaded = .init_single_threaded;
    defer threaded.deinit();

    var client = try support.initPublicClient(&threaded);
    defer client.deinit();

    var response = try client.models.list(.{});
    defer response.deinit();

    try std.testing.expect(response.data.len > 0);
}

test "models count integration" {
    try support.requireProfile(.discovery);
    var threaded: std.Io.Threaded = .init_single_threaded;
    defer threaded.deinit();

    var client = try support.initPublicClient(&threaded);
    defer client.deinit();

    var response = try client.models.count(.{}, .{});
    defer response.deinit();

    try std.testing.expect(response.data.count > 0);
}

test "providers list integration" {
    try support.requireProfile(.discovery);
    var threaded: std.Io.Threaded = .init_single_threaded;
    defer threaded.deinit();

    var client = try support.initPublicClient(&threaded);
    defer client.deinit();

    var response = try client.providers.list(.{});
    defer response.deinit();

    try std.testing.expect(response.data.len > 0);
}

test "datasets rankings daily integration" {
    try support.requireProfile(.standard);
    var threaded: std.Io.Threaded = .init_single_threaded;
    defer threaded.deinit();

    var client = try support.initPublicClient(&threaded);
    defer client.deinit();

    var response = try client.datasets.rankings_daily.get(.{}, .{});
    defer response.deinit();

    try std.testing.expect(response.data.len > 0);
}

test "current API key integration" {
    try support.requireProfile(.discovery);
    var threaded: std.Io.Threaded = .init_single_threaded;
    defer threaded.deinit();
    var client = try support.initPublicClient(&threaded);
    defer client.deinit();
    var response = try client.key.get(.{});
    defer response.deinit();
    try std.testing.expect(response.data.label.len > 0);
}

test "tool catalog discovery integration" {
    try support.requireProfile(.discovery);
    var threaded: std.Io.Threaded = .init_single_threaded;
    defer threaded.deinit();
    var client = try support.initPublicClient(&threaded);
    defer client.deinit();
    var list = try client.tools.list(.{ .limit = 2 }, .{});
    defer list.deinit();
    try std.testing.expect(list.total_count >= 0);
    if (list.data.len == 0) return;
    var tool = try client.tools.get(.{ .name = list.data[0].id }, .{});
    defer tool.deinit();
    try std.testing.expectEqualStrings(list.data[0].id, tool.data.id);
}

test "free model detail and provider endpoints integration" {
    try support.requireProfile(.discovery);
    var threaded: std.Io.Threaded = .init_single_threaded;
    defer threaded.deinit();
    var client = try support.initPublicClient(&threaded);
    defer client.deinit();
    var list = try client.models.list(.{});
    defer list.deinit();
    for (list.data) |model| {
        if (!std.mem.endsWith(u8, model.id, ":free")) continue;
        const slash = std.mem.indexOfScalar(u8, model.id, '/') orelse continue;
        const request: openrouter.ModelsGetRequest = .{ .author = model.id[0..slash], .slug = model.id[slash + 1 ..] };
        var detail = try client.models.get(request, .{});
        defer detail.deinit();
        try std.testing.expectEqualStrings(model.id, detail.data.id);
        var endpoints = try client.models.endpoints.list(.{ .author = request.author, .slug = request.slug }, .{});
        defer endpoints.deinit();
        try std.testing.expectEqualStrings(model.id, endpoints.data.id);
        return;
    }
    return error.NoFreeModelAvailable;
}
