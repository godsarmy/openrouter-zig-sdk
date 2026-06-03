const std = @import("std");
const openrouter = @import("openrouter");

test "list models integration" {
    const allocator = std.testing.allocator;
    const api_key = env("OPENROUTER_API_KEY") orelse return;

    var threaded: std.Io.Threaded = .init_single_threaded;
    defer threaded.deinit();

    var client = try openrouter.Client.init(allocator, threaded.io(), .{
        .api_key = api_key,
        .http_referer = env("OPENROUTER_HTTP_REFERER"),
        .x_title = env("OPENROUTER_APP_TITLE"),
    });
    defer client.deinit();

    var response = try client.models.list(.{});
    defer response.deinit();

    try std.testing.expect(response.data.len > 0);
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
