//! Activity API.

const std = @import("std");

const config_mod = @import("config.zig");
const errors = @import("errors.zig");
const http = @import("http.zig");
const json = @import("json.zig");
const options_mod = @import("options.zig");
const query_mod = @import("query.zig");

pub const GetRequest = struct {
    date: ?[]const u8 = null,
    api_key_hash: ?[]const u8 = null,
    user_id: ?[]const u8 = null,
};

pub const GetResponse = struct {
    arena: std.heap.ArenaAllocator,
    data: []ActivityItem,

    pub fn deinit(self: *GetResponse) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

pub const ActivityItem = struct {
    byok_usage_inference: f64,
    completion_tokens: u64,
    date: []const u8,
    endpoint_id: []const u8,
    model: []const u8,
    model_permaslug: []const u8,
    prompt_tokens: u64,
    provider_name: []const u8,
    reasoning_tokens: u64,
    requests: u64,
    usage: f64,
};

const WireGetResponse = struct {
    data: []ActivityItem,
};

pub fn get(client: anytype, request: GetRequest, request_options: options_mod.RequestOptions) !GetResponse {
    const query = try queryString(client.allocator, request);
    defer client.allocator.free(query);

    var prepared = try http.prepareRequest(client.allocator, client.config, .{
        .method = .GET,
        .path = "/activity",
        .query = query,
    }, request_options);
    defer prepared.deinit();

    var response = try http.execute(client.allocator, &client.http_client, prepared);
    defer response.deinit();

    return parseGetResponse(client.allocator, response);
}

pub fn getWithTransport(
    allocator: std.mem.Allocator,
    config: config_mod.Config,
    transport: anytype,
    request: GetRequest,
    request_options: options_mod.RequestOptions,
) !GetResponse {
    const query = try queryString(allocator, request);
    defer allocator.free(query);

    var prepared = try http.prepareRequest(allocator, config, .{
        .method = .GET,
        .path = "/activity",
        .query = query,
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

pub fn queryString(allocator: std.mem.Allocator, request: GetRequest) ![]u8 {
    return query_mod.build(allocator, &.{
        .{ .name = "date", .value = request.date },
        .{ .name = "api_key_hash", .value = request.api_key_hash },
        .{ .name = "user_id", .value = request.user_id },
    });
}

test "activity get parses response and ignores unknown fields" {
    const body =
        \\{
        \\  "data": [
        \\    {
        \\      "date": "2025-08-24",
        \\      "model": "openai/gpt-4.1",
        \\      "model_permaslug": "openai/gpt-4.1-2025-04-14",
        \\      "endpoint_id": "550e8400-e29b-41d4-a716-446655440000",
        \\      "provider_name": "OpenAI",
        \\      "usage": 0.015,
        \\      "byok_usage_inference": 0.012,
        \\      "requests": 5,
        \\      "prompt_tokens": 50,
        \\      "completion_tokens": 125,
        \\      "reasoning_tokens": 25,
        \\      "unknown": true
        \\    }
        \\  ],
        \\  "unknown": true
        \\}
    ;

    var result = try getWithTransport(std.testing.allocator, config_mod.Config{ .api_key = "test-key" }, http.FakeTransport{ .body = body }, .{}, .{});
    defer result.deinit();

    try std.testing.expectEqual(@as(usize, 1), result.data.len);
    try std.testing.expectEqualStrings("2025-08-24", result.data[0].date);
    try std.testing.expectEqualStrings("openai/gpt-4.1", result.data[0].model);
    try std.testing.expectEqualStrings("openai/gpt-4.1-2025-04-14", result.data[0].model_permaslug);
    try std.testing.expectEqualStrings("550e8400-e29b-41d4-a716-446655440000", result.data[0].endpoint_id);
    try std.testing.expectEqualStrings("OpenAI", result.data[0].provider_name);
    try std.testing.expectEqual(@as(f64, 0.015), result.data[0].usage);
    try std.testing.expectEqual(@as(f64, 0.012), result.data[0].byok_usage_inference);
    try std.testing.expectEqual(@as(u64, 5), result.data[0].requests);
    try std.testing.expectEqual(@as(u64, 50), result.data[0].prompt_tokens);
    try std.testing.expectEqual(@as(u64, 125), result.data[0].completion_tokens);
    try std.testing.expectEqual(@as(u64, 25), result.data[0].reasoning_tokens);
}

test "activity get sends GET /activity without query" {
    const query = try queryString(std.testing.allocator, .{});
    defer std.testing.allocator.free(query);

    var prepared = try http.prepareRequest(std.testing.allocator, .{ .api_key = "test-key" }, .{
        .method = .GET,
        .path = "/activity",
        .query = query,
    }, .{});
    defer prepared.deinit();

    try std.testing.expectEqual(std.http.Method.GET, prepared.method);
    try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/activity", prepared.url);
}

test "activity get sends escaped optional query params" {
    const query = try queryString(std.testing.allocator, .{
        .date = "2025-08-24",
        .api_key_hash = "hash/with space",
        .user_id = "user-123",
    });
    defer std.testing.allocator.free(query);

    var prepared = try http.prepareRequest(std.testing.allocator, .{ .api_key = "test-key" }, .{
        .method = .GET,
        .path = "/activity",
        .query = query,
    }, .{});
    defer prepared.deinit();

    try std.testing.expectEqual(std.http.Method.GET, prepared.method);
    try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/activity?date=2025-08-24&api_key_hash=hash%2Fwith%20space&user_id=user-123", prepared.url);
}

test "activity get maps error status to ApiError" {
    try std.testing.expectError(error.ApiError, getWithTransport(
        std.testing.allocator,
        config_mod.Config{ .api_key = "test-key" },
        http.FakeTransport{ .status = .forbidden, .body = "{\"error\":{\"message\":\"management key required\"}}" },
        .{},
        .{},
    ));
}
