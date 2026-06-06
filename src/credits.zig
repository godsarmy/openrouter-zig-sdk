//! Credits API.

const std = @import("std");

const config_mod = @import("config.zig");
const errors = @import("errors.zig");
const http = @import("http.zig");
const json = @import("json.zig");
const options_mod = @import("options.zig");

pub const GetResponse = struct {
    arena: std.heap.ArenaAllocator,
    data: Credits,

    pub fn deinit(self: *GetResponse) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

pub const Credits = struct {
    total_credits: f64,
    total_usage: f64,
};

const WireGetResponse = struct {
    data: Credits,
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
        .path = "/credits",
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

test "credits get parses response and ignores unknown fields" {
    const body =
        \\{
        \\  "data": {
        \\    "total_credits": 10.5,
        \\    "total_usage": 2.25,
        \\    "unknown": true
        \\  }
        \\}
    ;

    var result = try getWithTransport(std.testing.allocator, config_mod.Config{ .api_key = "test-key" }, http.FakeTransport{ .body = body }, .{});
    defer result.deinit();

    try std.testing.expectEqual(@as(f64, 10.5), result.data.total_credits);
    try std.testing.expectEqual(@as(f64, 2.25), result.data.total_usage);
}

test "credits get sends GET /credits" {
    var prepared = try http.prepareRequest(std.testing.allocator, .{ .api_key = "test-key" }, .{
        .method = .GET,
        .path = "/credits",
    }, .{});
    defer prepared.deinit();

    try std.testing.expectEqual(std.http.Method.GET, prepared.method);
    try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/credits", prepared.url);
}

test "credits get maps error status to ApiError" {
    try std.testing.expectError(error.ApiError, getWithTransport(
        std.testing.allocator,
        config_mod.Config{ .api_key = "test-key" },
        http.FakeTransport{ .status = .forbidden, .body = "{\"error\":{\"message\":\"management key required\"}}" },
        .{},
    ));
}
