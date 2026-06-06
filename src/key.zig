//! Current API key API.

const std = @import("std");

const config_mod = @import("config.zig");
const errors = @import("errors.zig");
const http = @import("http.zig");
const json = @import("json.zig");
const options_mod = @import("options.zig");

pub const GetResponse = struct {
    arena: std.heap.ArenaAllocator,
    data: ApiKey,

    pub fn deinit(self: *GetResponse) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

pub const ApiKey = struct {
    byok_usage: f64 = 0,
    byok_usage_daily: f64 = 0,
    byok_usage_monthly: f64 = 0,
    byok_usage_weekly: f64 = 0,
    creator_user_id: ?[]const u8 = null,
    expires_at: ?[]const u8 = null,
    include_byok_in_limit: bool = false,
    is_free_tier: bool = false,
    is_management_key: bool = false,
    is_provisioning_key: bool = false,
    label: []const u8,
    limit: ?f64 = null,
    limit_remaining: ?f64 = null,
    limit_reset: ?[]const u8 = null,
    rate_limit: RateLimit,
    usage: f64 = 0,
    usage_daily: f64 = 0,
    usage_monthly: f64 = 0,
    usage_weekly: f64 = 0,
};

pub const RateLimit = struct {
    interval: []const u8,
    note: []const u8,
    requests: i64,
};

const WireGetResponse = struct {
    data: ApiKey,
};

pub fn get(client: anytype, request_options: options_mod.RequestOptions) !GetResponse {
    return getWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, request_options);
}

pub fn getWithTransport(
    allocator: std.mem.Allocator,
    config: config_mod.Config,
    transport: anytype,
    request_options: options_mod.RequestOptions,
) !GetResponse {
    var prepared = try http.prepareRequest(allocator, config, .{
        .method = .GET,
        .path = "/key",
    }, request_options);
    defer prepared.deinit();

    var response = try transport.execute(allocator, prepared);
    defer response.deinit();

    return parseGetResponse(allocator, response);
}

pub fn parseGetResponse(allocator: std.mem.Allocator, response: http.HttpResponse) !GetResponse {
    if (errors.isErrorStatus(@intFromEnum(response.status))) return error.ApiError;

    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const arena_allocator = arena.allocator();

    const owned_body = try arena_allocator.dupe(u8, response.body);
    const parsed = try json.parseResponseLeaky(WireGetResponse, arena_allocator, owned_body);
    return .{
        .arena = arena,
        .data = parsed.data,
    };
}

test "key get parses current key response and ignores unknown fields" {
    const body =
        \\{
        \\  "data": {
        \\    "byok_usage": 0,
        \\    "byok_usage_daily": 0,
        \\    "byok_usage_monthly": 0,
        \\    "byok_usage_weekly": 0,
        \\    "creator_user_id": "user_123",
        \\    "expires_at": null,
        \\    "include_byok_in_limit": false,
        \\    "is_free_tier": false,
        \\    "is_management_key": true,
        \\    "is_provisioning_key": false,
        \\    "label": "My API Key",
        \\    "limit": 10,
        \\    "limit_remaining": 7.5,
        \\    "limit_reset": null,
        \\    "rate_limit": {
        \\      "interval": "1m",
        \\      "note": "legacy",
        \\      "requests": -1
        \\    },
        \\    "usage": 2.5,
        \\    "usage_daily": 1.25,
        \\    "usage_monthly": 2.5,
        \\    "usage_weekly": 2.5,
        \\    "unknown": true
        \\  }
        \\}
    ;

    var result = try getWithTransport(std.testing.allocator, config_mod.Config{ .api_key = "test-key" }, http.FakeTransport{ .body = body }, .{});
    defer result.deinit();

    try std.testing.expectEqualStrings("user_123", result.data.creator_user_id.?);
    try std.testing.expectEqualStrings("My API Key", result.data.label);
    try std.testing.expect(result.data.is_management_key);
    try std.testing.expectEqual(@as(f64, 10), result.data.limit.?);
    try std.testing.expectEqual(@as(f64, 7.5), result.data.limit_remaining.?);
    try std.testing.expectEqualStrings("1m", result.data.rate_limit.interval);
    try std.testing.expectEqual(@as(i64, -1), result.data.rate_limit.requests);
    try std.testing.expectEqual(@as(f64, 2.5), result.data.usage);
}

test "key get sends GET /key" {
    var prepared = try http.prepareRequest(std.testing.allocator, .{ .api_key = "test-key" }, .{
        .method = .GET,
        .path = "/key",
    }, .{});
    defer prepared.deinit();

    try std.testing.expectEqual(std.http.Method.GET, prepared.method);
    try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/key", prepared.url);
}

test "key get maps error status to ApiError" {
    try std.testing.expectError(error.ApiError, getWithTransport(
        std.testing.allocator,
        config_mod.Config{ .api_key = "test-key" },
        http.FakeTransport{ .status = .unauthorized, .body = "{\"error\":{\"message\":\"invalid key\"}}" },
        .{},
    ));
}
