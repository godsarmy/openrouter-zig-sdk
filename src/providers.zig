//! Providers API.

const std = @import("std");

const config_mod = @import("config.zig");
const errors = @import("errors.zig");
const http = @import("http.zig");
const json = @import("json.zig");
const options_mod = @import("options.zig");

pub const ListResponse = struct {
    arena: std.heap.ArenaAllocator,
    data: []Provider,

    pub fn deinit(self: *ListResponse) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

pub const Provider = struct {
    name: []const u8,
    slug: []const u8,
    privacy_policy_url: ?[]const u8,
    datacenters: ?[]const []const u8 = null,
    headquarters: ?[]const u8 = null,
    status_page_url: ?[]const u8 = null,
    terms_of_service_url: ?[]const u8 = null,
};

const WireListResponse = struct {
    data: []Provider,
};

pub fn list(client: anytype, request_options: options_mod.RequestOptions) !ListResponse {
    var prepared = try http.prepareRequest(client.allocator, client.config, .{
        .method = .GET,
        .path = "/providers",
    }, request_options);
    defer prepared.deinit();

    var response = try http.execute(client.allocator, &client.http_client, prepared);
    defer response.deinit();

    return parseListResponse(client.allocator, response);
}

pub fn listWithTransport(
    allocator: std.mem.Allocator,
    config: config_mod.Config,
    transport: anytype,
    request_options: options_mod.RequestOptions,
) !ListResponse {
    var prepared = try http.prepareRequest(allocator, config, .{
        .method = .GET,
        .path = "/providers",
    }, request_options);
    defer prepared.deinit();

    var response = try transport.execute(allocator, prepared);
    defer response.deinit();

    return parseListResponse(allocator, response);
}

pub fn parseListResponse(allocator: std.mem.Allocator, response: http.HttpResponse) !ListResponse {
    if (errors.isErrorStatus(@intFromEnum(response.status))) return error.ApiError;

    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const arena_allocator = arena.allocator();

    const owned_body = try arena_allocator.dupe(u8, response.body);
    const parsed = try json.parseResponseLeaky(WireListResponse, arena_allocator, owned_body);
    return .{
        .arena = arena,
        .data = parsed.data,
    };
}

test "providers list parses response and ignores unknown fields" {
    const body =
        \\{
        \\  "data": [
        \\    {
        \\      "name": "OpenAI",
        \\      "slug": "openai",
        \\      "privacy_policy_url": "https://openai.com/policies/privacy-policy",
        \\      "datacenters": ["US"],
        \\      "headquarters": "US",
        \\      "status_page_url": "https://status.openai.com",
        \\      "terms_of_service_url": null,
        \\      "unknown": true
        \\    }
        \\  ]
        \\}
    ;

    var result = try listWithTransport(std.testing.allocator, config_mod.Config{ .api_key = "test-key" }, http.FakeTransport{ .body = body }, .{});
    defer result.deinit();

    try std.testing.expectEqual(@as(usize, 1), result.data.len);
    try std.testing.expectEqualStrings("OpenAI", result.data[0].name);
    try std.testing.expectEqualStrings("openai", result.data[0].slug);
    try std.testing.expectEqualStrings("https://openai.com/policies/privacy-policy", result.data[0].privacy_policy_url.?);
    try std.testing.expectEqualStrings("US", result.data[0].datacenters.?[0]);
    try std.testing.expectEqualStrings("US", result.data[0].headquarters.?);
    try std.testing.expectEqualStrings("https://status.openai.com", result.data[0].status_page_url.?);
    try std.testing.expectEqual(null, result.data[0].terms_of_service_url);
}

test "providers list sends GET /providers" {
    var prepared = try http.prepareRequest(std.testing.allocator, .{ .api_key = "test-key" }, .{
        .method = .GET,
        .path = "/providers",
    }, .{});
    defer prepared.deinit();

    try std.testing.expectEqual(std.http.Method.GET, prepared.method);
    try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/providers", prepared.url);
}

test "providers list maps error status to ApiError" {
    try std.testing.expectError(error.ApiError, listWithTransport(
        std.testing.allocator,
        config_mod.Config{ .api_key = "test-key" },
        http.FakeTransport{ .status = .internal_server_error, .body = "{\"error\":{\"message\":\"server error\"}}" },
        .{},
    ));
}
