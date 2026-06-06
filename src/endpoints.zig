//! Endpoints discovery API.

const std = @import("std");

const config_mod = @import("config.zig");
const errors = @import("errors.zig");
const http = @import("http.zig");
const json = @import("json.zig");
const models_mod = @import("models.zig");
const options_mod = @import("options.zig");

pub const ZdrListResponse = struct {
    arena: std.heap.ArenaAllocator,
    data: []models_mod.PublicEndpoint,

    pub fn deinit(self: *ZdrListResponse) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

const WireZdrListResponse = struct {
    data: []models_mod.PublicEndpoint,
};

pub fn listZdr(client: anytype, request_options: options_mod.RequestOptions) !ZdrListResponse {
    return listZdrWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, request_options);
}

pub fn listZdrWithTransport(
    allocator: std.mem.Allocator,
    config: config_mod.Config,
    transport: anytype,
    request_options: options_mod.RequestOptions,
) !ZdrListResponse {
    var prepared = try http.prepareRequest(allocator, config, .{
        .method = .GET,
        .path = "/endpoints/zdr",
    }, request_options);
    defer prepared.deinit();

    var response = try transport.execute(allocator, prepared);
    defer response.deinit();

    return parseZdrListResponse(allocator, response);
}

pub fn parseZdrListResponse(allocator: std.mem.Allocator, response: http.HttpResponse) !ZdrListResponse {
    if (errors.isErrorStatus(@intFromEnum(response.status))) return error.ApiError;

    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const arena_allocator = arena.allocator();

    const owned_body = try arena_allocator.dupe(u8, response.body);
    const parsed = try json.parseResponseLeaky(WireZdrListResponse, arena_allocator, owned_body);
    return .{
        .arena = arena,
        .data = parsed.data,
    };
}

test "endpoints zdr list parses response and ignores unknown fields" {
    const body =
        \\{
        \\  "data": [
        \\    {
        \\      "context_length": 8192,
        \\      "latency_last_30m": { "p50": 120, "p75": 150, "p90": 180, "p99": 250 },
        \\      "max_completion_tokens": null,
        \\      "max_prompt_tokens": null,
        \\      "model_id": "openai/gpt-4",
        \\      "model_name": "GPT-4",
        \\      "name": "GPT-4 on OpenAI",
        \\      "pricing": { "completion": "0.00006", "prompt": "0.00003" },
        \\      "provider_name": "OpenAI",
        \\      "quantization": "fp16",
        \\      "status": "0",
        \\      "supported_parameters": ["temperature", "top_p"],
        \\      "supports_implicit_caching": false,
        \\      "tag": "default",
        \\      "throughput_last_30m": { "p50": 40.2, "p75": 55.1, "p90": 68.7, "p99": 90.3 },
        \\      "uptime_last_1d": 99.9,
        \\      "uptime_last_30m": 99.8,
        \\      "uptime_last_5m": 100,
        \\      "unknown": true
        \\    }
        \\  ]
        \\}
    ;

    var result = try listZdrWithTransport(std.testing.allocator, config_mod.Config{ .api_key = "test-key" }, http.FakeTransport{ .body = body }, .{});
    defer result.deinit();

    try std.testing.expectEqual(@as(usize, 1), result.data.len);
    try std.testing.expectEqualStrings("GPT-4 on OpenAI", result.data[0].name);
    try std.testing.expectEqualStrings("OpenAI", result.data[0].provider_name);
    try std.testing.expectEqual(@as(u32, 8192), result.data[0].context_length);
    try std.testing.expectEqualStrings("0.00003", result.data[0].pricing.prompt.?);
    try std.testing.expectEqual(@as(?f64, 120), result.data[0].latency_last_30m.?.p50);
    try std.testing.expect(!result.data[0].supports_implicit_caching);
    try std.testing.expectEqualStrings("default", result.data[0].tag);
}

test "endpoints zdr list sends GET /endpoints/zdr" {
    var prepared = try http.prepareRequest(std.testing.allocator, .{ .api_key = "test-key" }, .{
        .method = .GET,
        .path = "/endpoints/zdr",
    }, .{});
    defer prepared.deinit();

    try std.testing.expectEqual(std.http.Method.GET, prepared.method);
    try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/endpoints/zdr", prepared.url);
}

test "endpoints zdr list maps error status to ApiError" {
    try std.testing.expectError(error.ApiError, listZdrWithTransport(
        std.testing.allocator,
        config_mod.Config{ .api_key = "test-key" },
        http.FakeTransport{ .status = .internal_server_error, .body = "{\"error\":{\"message\":\"server error\"}}" },
        .{},
    ));
}
