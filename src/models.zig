//! Models API.

const std = @import("std");

const errors = @import("errors.zig");
const config_mod = @import("config.zig");
const http = @import("http.zig");
const json = @import("json.zig");
const options_mod = @import("options.zig");

pub const ListResponse = struct {
    arena: std.heap.ArenaAllocator,
    data: []Model,

    pub fn deinit(self: *ListResponse) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

pub const Model = struct {
    id: []const u8,
    name: ?[]const u8 = null,
    description: ?[]const u8 = null,
    context_length: ?u32 = null,
    pricing: ?Pricing = null,
};

pub const Pricing = struct {
    prompt: ?[]const u8 = null,
    completion: ?[]const u8 = null,
    image: ?[]const u8 = null,
    request: ?[]const u8 = null,
    web_search: ?[]const u8 = null,
    internal_reasoning: ?[]const u8 = null,
    input_cache_read: ?[]const u8 = null,
    input_cache_write: ?[]const u8 = null,
    audio: ?[]const u8 = null,
    audio_output: ?[]const u8 = null,
    image_output: ?[]const u8 = null,
    image_token: ?[]const u8 = null,
    input_audio_cache: ?[]const u8 = null,
    discount: ?f64 = null,
};

const WireListResponse = struct {
    data: []Model,
};

pub fn list(client: anytype, request_options: options_mod.RequestOptions) !ListResponse {
    var prepared = try http.prepareRequest(client.allocator, client.config, .{
        .method = .GET,
        .path = "/models",
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
        .path = "/models",
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

test "models list parses response and ignores unknown fields" {
    const body =
        \\{
        \\  "data": [
        \\    {
        \\      "id": "openai/gpt-4o-mini",
        \\      "name": "GPT-4o mini",
        \\      "description": "Small model",
        \\      "context_length": 128000,
        \\      "pricing": {
        \\        "prompt": "0.00000015",
        \\        "completion": "0.0000006",
        \\        "web_search": "0",
        \\        "discount": 0
        \\      },
        \\      "unknown": true
        \\    }
        \\  ]
        \\}
    ;

    var result = try listWithTransport(std.testing.allocator, config_mod.Config{ .api_key = "test-key" }, http.FakeTransport{ .body = body }, .{});
    defer result.deinit();

    try std.testing.expectEqual(@as(usize, 1), result.data.len);
    try std.testing.expectEqualStrings("openai/gpt-4o-mini", result.data[0].id);
    try std.testing.expectEqualStrings("GPT-4o mini", result.data[0].name.?);
    try std.testing.expectEqual(@as(?u32, 128000), result.data[0].context_length);
    try std.testing.expectEqualStrings("0.00000015", result.data[0].pricing.?.prompt.?);
    try std.testing.expectEqual(@as(?f64, 0), result.data[0].pricing.?.discount);
}

test "models list sends GET /models" {
    var prepared = try http.prepareRequest(std.testing.allocator, .{ .api_key = "test-key" }, .{
        .method = .GET,
        .path = "/models",
    }, .{});
    defer prepared.deinit();

    try std.testing.expectEqual(std.http.Method.GET, prepared.method);
    try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/models", prepared.url);
}

test "models list maps error status to ApiError" {
    try std.testing.expectError(error.ApiError, listWithTransport(
        std.testing.allocator,
        config_mod.Config{ .api_key = "test-key" },
        http.FakeTransport{ .status = .unauthorized, .body = "{\"error\":{\"message\":\"bad key\"}}" },
        .{},
    ));
}
