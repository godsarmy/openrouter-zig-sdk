//! Generation metadata API.

const std = @import("std");

const config_mod = @import("config.zig");
const errors = @import("errors.zig");
const http = @import("http.zig");
const json = @import("json.zig");
const options_mod = @import("options.zig");

pub const GetRequest = struct {
    id: []const u8,
};

pub const GetResponse = struct {
    arena: std.heap.ArenaAllocator,
    data: Generation,

    pub fn deinit(self: *GetResponse) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

pub const ContentRequest = struct {
    id: []const u8,
};

pub const ContentResponse = struct {
    arena: std.heap.ArenaAllocator,
    data: GenerationContent,

    pub fn deinit(self: *ContentResponse) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

pub const Generation = struct {
    api_type: ?[]const u8,
    app_id: ?u64,
    cache_discount: ?f64,
    cancelled: ?bool,
    created_at: []const u8,
    external_user: ?[]const u8,
    finish_reason: ?[]const u8,
    generation_time: ?f64,
    http_referer: ?[]const u8,
    id: []const u8,
    is_byok: bool,
    latency: ?f64,
    model: []const u8,
    moderation_latency: ?f64,
    native_finish_reason: ?[]const u8,
    native_tokens_cached: ?u64,
    native_tokens_completion: ?u64,
    native_tokens_completion_images: ?u64,
    native_tokens_prompt: ?u64,
    native_tokens_reasoning: ?u64,
    num_fetches: ?u64,
    num_input_audio_prompt: ?u64,
    num_media_completion: ?u64,
    num_media_prompt: ?u64,
    num_search_results: ?u64,
    origin: []const u8,
    preset_id: ?[]const u8,
    provider_name: ?[]const u8,
    provider_responses: ?[]ProviderResponse,
    request_id: ?[]const u8,
    response_cache_source_id: ?[]const u8,
    router: ?[]const u8,
    service_tier: ?[]const u8,
    session_id: ?[]const u8,
    streamed: ?bool,
    tokens_completion: ?u64,
    tokens_prompt: ?u64,
    total_cost: f64,
    upstream_id: ?[]const u8,
    upstream_inference_cost: ?f64,
    usage: f64,
    user_agent: ?[]const u8,
    web_search_engine: ?[]const u8,
};

pub const ProviderResponse = struct {
    endpoint_id: ?[]const u8,
    id: ?[]const u8,
    is_byok: ?bool,
    latency: ?f64,
    model_permaslug: ?[]const u8,
    provider_name: ?[]const u8,
    status: ?f64,
};

pub const GenerationContent = struct {
    input: ContentInput,
    output: ContentOutput,
};

pub const ContentInput = struct {
    prompt: ?[]const u8 = null,
    messages: ?[]std.json.Value = null,
};

pub const ContentOutput = struct {
    completion: ?[]const u8,
    reasoning: ?[]const u8,
};

const WireGetResponse = struct {
    data: Generation,
};

const WireContentResponse = struct {
    data: GenerationContent,
};

pub fn get(client: anytype, request: GetRequest, request_options: options_mod.RequestOptions) !GetResponse {
    const query = try queryString(client.allocator, request);
    defer client.allocator.free(query);

    var prepared = try http.prepareRequest(client.allocator, client.config, .{
        .method = .GET,
        .path = "/generation",
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
        .path = "/generation",
        .query = query,
    }, request_options);
    defer prepared.deinit();

    var response = try transport.execute(allocator, prepared);
    defer response.deinit();

    return parseGetResponse(allocator, response);
}

pub fn content(client: anytype, request: ContentRequest, request_options: options_mod.RequestOptions) !ContentResponse {
    const query = try queryString(client.allocator, .{ .id = request.id });
    defer client.allocator.free(query);

    var prepared = try http.prepareRequest(client.allocator, client.config, .{
        .method = .GET,
        .path = "/generation/content",
        .query = query,
    }, request_options);
    defer prepared.deinit();

    var response = try http.execute(client.allocator, &client.http_client, prepared);
    defer response.deinit();

    return parseContentResponse(client.allocator, response);
}

pub fn contentWithTransport(
    allocator: std.mem.Allocator,
    config: config_mod.Config,
    transport: anytype,
    request: ContentRequest,
    request_options: options_mod.RequestOptions,
) !ContentResponse {
    const query = try queryString(allocator, .{ .id = request.id });
    defer allocator.free(query);

    var prepared = try http.prepareRequest(allocator, config, .{
        .method = .GET,
        .path = "/generation/content",
        .query = query,
    }, request_options);
    defer prepared.deinit();

    var response = try transport.execute(allocator, prepared);
    defer response.deinit();

    return parseContentResponse(allocator, response);
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

pub fn parseContentResponse(allocator: std.mem.Allocator, response: http.HttpResponse) !ContentResponse {
    if (errors.isErrorStatus(@intFromEnum(response.status))) return error.ApiError;

    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const arena_allocator = arena.allocator();

    const owned_body = try arena_allocator.dupe(u8, response.body);
    const parsed = try json.parseResponseLeaky(WireContentResponse, arena_allocator, owned_body);
    return .{
        .arena = arena,
        .data = parsed.data,
    };
}

pub fn queryString(allocator: std.mem.Allocator, request: GetRequest) ![]u8 {
    var query: std.ArrayList(u8) = .empty;
    errdefer query.deinit(allocator);

    try query.appendSlice(allocator, "id=");
    try percentEncode(allocator, &query, request.id);
    return try query.toOwnedSlice(allocator);
}

fn percentEncode(allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: []const u8) !void {
    const hex = "0123456789ABCDEF";
    for (value) |byte| {
        if (std.ascii.isAlphanumeric(byte) or byte == '-' or byte == '_' or byte == '.' or byte == '~') {
            try output.append(allocator, byte);
        } else {
            try output.appendSlice(allocator, &.{ '%', hex[byte >> 4], hex[byte & 0x0F] });
        }
    }
}

test "generation get parses response and ignores unknown fields" {
    const body =
        \\{
        \\  "data": {
        \\    "api_type": "completions",
        \\    "app_id": null,
        \\    "cache_discount": null,
        \\    "cancelled": false,
        \\    "created_at": "2024-07-15T23:33:19.433273+00:00",
        \\    "external_user": null,
        \\    "finish_reason": "stop",
        \\    "generation_time": 1200,
        \\    "http_referer": "https://example.com",
        \\    "id": "gen-123",
        \\    "is_byok": false,
        \\    "latency": 1250,
        \\    "model": "openai/gpt-4o-mini",
        \\    "moderation_latency": null,
        \\    "native_finish_reason": "stop",
        \\    "native_tokens_cached": 3,
        \\    "native_tokens_completion": 25,
        \\    "native_tokens_completion_images": 0,
        \\    "native_tokens_prompt": 10,
        \\    "native_tokens_reasoning": 5,
        \\    "num_fetches": 0,
        \\    "num_input_audio_prompt": 0,
        \\    "num_media_completion": 0,
        \\    "num_media_prompt": 1,
        \\    "num_search_results": 5,
        \\    "origin": "https://openrouter.ai/",
        \\    "preset_id": null,
        \\    "provider_name": "OpenAI",
        \\    "provider_responses": [
        \\      {"endpoint_id": "endpoint-1", "id": "upstream-1", "is_byok": false, "latency": 100, "model_permaslug": "openai/gpt-4o-mini", "provider_name": "OpenAI", "status": 200}
        \\    ],
        \\    "request_id": "req-123",
        \\    "response_cache_source_id": null,
        \\    "router": "openrouter/auto",
        \\    "service_tier": "priority",
        \\    "session_id": null,
        \\    "streamed": true,
        \\    "tokens_completion": 25,
        \\    "tokens_prompt": 10,
        \\    "total_cost": 0.0015,
        \\    "upstream_id": "chatcmpl-123",
        \\    "upstream_inference_cost": 0.0012,
        \\    "usage": 0.0015,
        \\    "user_agent": "zig-test",
        \\    "web_search_engine": null,
        \\    "unknown": true
        \\  }
        \\}
    ;

    var result = try getWithTransport(std.testing.allocator, config_mod.Config{ .api_key = "test-key" }, http.FakeTransport{ .body = body }, .{ .id = "gen-123" }, .{});
    defer result.deinit();

    try std.testing.expectEqualStrings("gen-123", result.data.id);
    try std.testing.expectEqualStrings("completions", result.data.api_type.?);
    try std.testing.expectEqualStrings("openai/gpt-4o-mini", result.data.model);
    try std.testing.expectEqual(@as(bool, false), result.data.is_byok);
    try std.testing.expectEqual(@as(?u64, 25), result.data.tokens_completion);
    try std.testing.expectEqual(@as(f64, 0.0015), result.data.total_cost);
    try std.testing.expectEqual(@as(usize, 1), result.data.provider_responses.?.len);
    try std.testing.expectEqual(@as(?f64, 200), result.data.provider_responses.?[0].status);
}

test "generation get sends GET /generation with escaped id" {
    const query = try queryString(std.testing.allocator, .{ .id = "gen 123/abc" });
    defer std.testing.allocator.free(query);

    var prepared = try http.prepareRequest(std.testing.allocator, .{ .api_key = "test-key" }, .{
        .method = .GET,
        .path = "/generation",
        .query = query,
    }, .{});
    defer prepared.deinit();

    try std.testing.expectEqual(std.http.Method.GET, prepared.method);
    try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/generation?id=gen%20123%2Fabc", prepared.url);
}

test "generation get maps error status to ApiError" {
    try std.testing.expectError(error.ApiError, getWithTransport(
        std.testing.allocator,
        config_mod.Config{ .api_key = "test-key" },
        http.FakeTransport{ .status = .not_found, .body = "{\"error\":{\"message\":\"not found\"}}" },
        .{ .id = "gen-missing" },
        .{},
    ));
}

test "generation content parses prompt response and ignores unknown fields" {
    const body =
        \\{
        \\  "data": {
        \\    "input": {
        \\      "prompt": "Say hello.",
        \\      "unknown": true
        \\    },
        \\    "output": {
        \\      "completion": "Hello!",
        \\      "reasoning": null,
        \\      "unknown": true
        \\    },
        \\    "unknown": true
        \\  }
        \\}
    ;

    var result = try contentWithTransport(std.testing.allocator, config_mod.Config{ .api_key = "test-key" }, http.FakeTransport{ .body = body }, .{ .id = "gen-123" }, .{});
    defer result.deinit();

    try std.testing.expectEqualStrings("Say hello.", result.data.input.prompt.?);
    try std.testing.expectEqual(null, result.data.input.messages);
    try std.testing.expectEqualStrings("Hello!", result.data.output.completion.?);
    try std.testing.expectEqual(null, result.data.output.reasoning);
}

test "generation content parses messages response" {
    const body =
        \\{
        \\  "data": {
        \\    "input": {
        \\      "messages": [
        \\        {"role": "user", "content": "Hi"}
        \\      ]
        \\    },
        \\    "output": {
        \\      "completion": null,
        \\      "reasoning": "Because."
        \\    }
        \\  }
        \\}
    ;

    var result = try contentWithTransport(std.testing.allocator, config_mod.Config{ .api_key = "test-key" }, http.FakeTransport{ .body = body }, .{ .id = "gen-123" }, .{});
    defer result.deinit();

    try std.testing.expectEqual(null, result.data.input.prompt);
    try std.testing.expectEqual(@as(usize, 1), result.data.input.messages.?.len);
    try std.testing.expectEqualStrings("Because.", result.data.output.reasoning.?);
}

test "generation content sends GET /generation/content with escaped id" {
    const query = try queryString(std.testing.allocator, .{ .id = "gen 123/abc" });
    defer std.testing.allocator.free(query);

    var prepared = try http.prepareRequest(std.testing.allocator, .{ .api_key = "test-key" }, .{
        .method = .GET,
        .path = "/generation/content",
        .query = query,
    }, .{});
    defer prepared.deinit();

    try std.testing.expectEqual(std.http.Method.GET, prepared.method);
    try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/generation/content?id=gen%20123%2Fabc", prepared.url);
}

test "generation content maps error status to ApiError" {
    try std.testing.expectError(error.ApiError, contentWithTransport(
        std.testing.allocator,
        config_mod.Config{ .api_key = "test-key" },
        http.FakeTransport{ .status = .not_found, .body = "{\"error\":{\"message\":\"not found\"}}" },
        .{ .id = "gen-missing" },
        .{},
    ));
}
