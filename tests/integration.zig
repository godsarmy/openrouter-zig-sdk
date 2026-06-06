const std = @import("std");
const openrouter = @import("openrouter");

test "list models integration" {
    var threaded: std.Io.Threaded = .init_single_threaded;
    defer threaded.deinit();

    const maybe_client = try initPublicClient(&threaded);
    var client = maybe_client orelse return;
    defer client.deinit();

    var response = try client.models.list(.{});
    defer response.deinit();

    try std.testing.expect(response.data.len > 0);
}

test "providers list integration" {
    var threaded: std.Io.Threaded = .init_single_threaded;
    defer threaded.deinit();

    const maybe_client = try initPublicClient(&threaded);
    var client = maybe_client orelse return;
    defer client.deinit();

    var response = try client.providers.list(.{});
    defer response.deinit();

    try std.testing.expect(response.data.len > 0);
}

test "datasets rankings daily integration" {
    var threaded: std.Io.Threaded = .init_single_threaded;
    defer threaded.deinit();

    const maybe_client = try initPublicClient(&threaded);
    var client = maybe_client orelse return;
    defer client.deinit();

    var response = try client.datasets.rankings_daily.get(.{}, .{});
    defer response.deinit();

    try std.testing.expect(response.data.len > 0);
}

test "generation integration" {
    var threaded: std.Io.Threaded = .init_single_threaded;
    defer threaded.deinit();

    const generation_id = env("OPENROUTER_GENERATION_ID") orelse return;
    const maybe_client = try initPublicClient(&threaded);
    var client = maybe_client orelse return;
    defer client.deinit();

    var response = try client.generation.get(.{ .id = generation_id }, .{});
    defer response.deinit();

    try std.testing.expect(response.data.id.len > 0);
}

test "generation content integration" {
    var threaded: std.Io.Threaded = .init_single_threaded;
    defer threaded.deinit();

    const generation_id = env("OPENROUTER_GENERATION_ID") orelse return;
    const maybe_client = try initPublicClient(&threaded);
    var client = maybe_client orelse return;
    defer client.deinit();

    var response = try client.generation.content(.{ .id = generation_id }, .{});
    defer response.deinit();

    try std.testing.expect(response.data.input.prompt != null or response.data.input.messages != null);
}

test "credits integration with management key" {
    var threaded: std.Io.Threaded = .init_single_threaded;
    defer threaded.deinit();

    const maybe_client = try initManagementClient(&threaded);
    var client = maybe_client orelse return;
    defer client.deinit();

    var response = try client.credits.get(.{});
    defer response.deinit();

    try std.testing.expect(response.data.total_credits >= 0);
}

test "activity integration with management key" {
    var threaded: std.Io.Threaded = .init_single_threaded;
    defer threaded.deinit();

    const maybe_client = try initManagementClient(&threaded);
    var client = maybe_client orelse return;
    defer client.deinit();

    var response = try client.activity.get(.{}, .{});
    defer response.deinit();

    if (response.data.len > 0) {
        try std.testing.expect(response.data[0].date.len > 0);
        try std.testing.expect(response.data[0].model.len > 0);
    }
}

fn env(name: []const u8) ?[]const u8 {
    var i: usize = 0;
    while (std.c.environ[i]) |entry| : (i += 1) {
        const item = std.mem.span(entry);
        if (item.len > name.len and item[name.len] == '=' and std.mem.eql(u8, item[0..name.len], name)) {
            return item[name.len + 1 ..];
        }
    }
    return null;
}

fn initPublicClient(threaded: *std.Io.Threaded) !?openrouter.Client {
    const api_key = env("OPENROUTER_API_KEY") orelse return null;
    return try initClient(threaded, api_key);
}

fn initManagementClient(threaded: *std.Io.Threaded) !?openrouter.Client {
    const api_key = env("OPENROUTER_MANAGEMENT_API_KEY") orelse return null;
    return try initClient(threaded, api_key);
}

fn initClient(threaded: *std.Io.Threaded, api_key: []const u8) !openrouter.Client {
    const allocator = std.testing.allocator;

    return try openrouter.Client.init(allocator, threaded.io(), .{
        .api_key = api_key,
        .http_referer = env("OPENROUTER_HTTP_REFERER"),
        .x_title = env("OPENROUTER_APP_TITLE"),
    });
}
