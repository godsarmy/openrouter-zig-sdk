//! Models API.

const std = @import("std");

const errors = @import("errors.zig");
const config_mod = @import("config.zig");
const http = @import("http.zig");
const json = @import("json.zig");
const options_mod = @import("options.zig");
const query_mod = @import("query.zig");

pub const ListResponse = struct {
    arena: std.heap.ArenaAllocator,
    data: []Model,

    pub fn deinit(self: *ListResponse) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

pub const CountRequest = struct {
    output_modalities: ?[]const u8 = null,
};

pub const GetRequest = struct {
    author: []const u8,
    slug: []const u8,
};

pub const EndpointsListRequest = struct {
    author: []const u8,
    slug: []const u8,
};

pub const CountResponse = struct {
    arena: std.heap.ArenaAllocator,
    data: Count,

    pub fn deinit(self: *CountResponse) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

pub const GetResponse = struct {
    arena: std.heap.ArenaAllocator,
    data: Model,

    pub fn deinit(self: *GetResponse) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

pub const EndpointsListResponse = struct {
    arena: std.heap.ArenaAllocator,
    data: ModelEndpoints,

    pub fn deinit(self: *EndpointsListResponse) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

pub const UserListResponse = ListResponse;

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

pub const Architecture = struct {
    input_modalities: []const []const u8,
    instruct_type: ?[]const u8 = null,
    modality: ?[]const u8 = null,
    output_modalities: []const []const u8,
    tokenizer: ?[]const u8 = null,
};

pub const LatencyStats = struct {
    p50: ?f64 = null,
    p75: ?f64 = null,
    p90: ?f64 = null,
    p99: ?f64 = null,
};

pub const PublicEndpoint = struct {
    context_length: u32,
    latency_last_30m: ?LatencyStats = null,
    max_completion_tokens: ?u32 = null,
    max_prompt_tokens: ?u32 = null,
    model_id: []const u8,
    model_name: []const u8,
    name: []const u8,
    pricing: Pricing,
    provider_name: []const u8,
    quantization: ?[]const u8 = null,
    supported_parameters: []const []const u8,
    supports_implicit_caching: bool,
    tag: []const u8,
    throughput_last_30m: ?LatencyStats = null,
    uptime_last_1d: ?f64 = null,
    uptime_last_30m: ?f64 = null,
    uptime_last_5m: ?f64 = null,
};

pub const ModelEndpoints = struct {
    architecture: Architecture,
    created: i64,
    description: []const u8,
    endpoints: []PublicEndpoint,
    id: []const u8,
    name: []const u8,
};

pub const Count = struct {
    count: u64,
};

const WireListResponse = struct {
    data: []Model,
};

const WireCountResponse = struct {
    data: Count,
};

const WireGetResponse = struct {
    data: Model,
};

const WireEndpointsListResponse = struct {
    data: ModelEndpoints,
};

pub fn list(client: anytype, request_options: options_mod.RequestOptions) !ListResponse {
    return listWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, request_options);
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

pub fn listUser(client: anytype, request_options: options_mod.RequestOptions) !UserListResponse {
    return listUserWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, request_options);
}

pub fn listUserWithTransport(
    allocator: std.mem.Allocator,
    config: config_mod.Config,
    transport: anytype,
    request_options: options_mod.RequestOptions,
) !UserListResponse {
    var prepared = try http.prepareRequest(allocator, config, .{
        .method = .GET,
        .path = "/models/user",
    }, request_options);
    defer prepared.deinit();

    var response = try transport.execute(allocator, prepared);
    defer response.deinit();

    return parseListResponse(allocator, response);
}

pub fn count(client: anytype, request: CountRequest, request_options: options_mod.RequestOptions) !CountResponse {
    return countWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, request, request_options);
}

pub fn get(client: anytype, request: GetRequest, request_options: options_mod.RequestOptions) !GetResponse {
    return getWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, request, request_options);
}

pub fn getWithTransport(
    allocator: std.mem.Allocator,
    config: config_mod.Config,
    transport: anytype,
    request: GetRequest,
    request_options: options_mod.RequestOptions,
) !GetResponse {
    const path = try getPath(allocator, request);
    defer allocator.free(path);

    var prepared = try http.prepareRequest(allocator, config, .{
        .method = .GET,
        .path = path,
    }, request_options);
    defer prepared.deinit();

    var response = try transport.execute(allocator, prepared);
    defer response.deinit();

    return parseGetResponse(allocator, response);
}

pub fn listEndpoints(client: anytype, request: EndpointsListRequest, request_options: options_mod.RequestOptions) !EndpointsListResponse {
    return listEndpointsWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, request, request_options);
}

pub fn listEndpointsWithTransport(
    allocator: std.mem.Allocator,
    config: config_mod.Config,
    transport: anytype,
    request: EndpointsListRequest,
    request_options: options_mod.RequestOptions,
) !EndpointsListResponse {
    const path = try endpointsPath(allocator, request);
    defer allocator.free(path);

    var prepared = try http.prepareRequest(allocator, config, .{
        .method = .GET,
        .path = path,
    }, request_options);
    defer prepared.deinit();

    var response = try transport.execute(allocator, prepared);
    defer response.deinit();

    return parseEndpointsListResponse(allocator, response);
}

pub fn countWithTransport(
    allocator: std.mem.Allocator,
    config: config_mod.Config,
    transport: anytype,
    request: CountRequest,
    request_options: options_mod.RequestOptions,
) !CountResponse {
    const query = try countQueryString(allocator, request);
    defer allocator.free(query);

    var prepared = try http.prepareRequest(allocator, config, .{
        .method = .GET,
        .path = "/models/count",
        .query = query,
    }, request_options);
    defer prepared.deinit();

    var response = try transport.execute(allocator, prepared);
    defer response.deinit();

    return parseCountResponse(allocator, response);
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

pub fn parseCountResponse(allocator: std.mem.Allocator, response: http.HttpResponse) !CountResponse {
    if (errors.isErrorStatus(@intFromEnum(response.status))) return error.ApiError;

    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const arena_allocator = arena.allocator();

    const owned_body = try arena_allocator.dupe(u8, response.body);
    const parsed = try json.parseResponseLeaky(WireCountResponse, arena_allocator, owned_body);
    return .{
        .arena = arena,
        .data = parsed.data,
    };
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

pub fn parseEndpointsListResponse(allocator: std.mem.Allocator, response: http.HttpResponse) !EndpointsListResponse {
    if (errors.isErrorStatus(@intFromEnum(response.status))) return error.ApiError;

    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const arena_allocator = arena.allocator();

    const owned_body = try arena_allocator.dupe(u8, response.body);
    const parsed = try json.parseResponseLeaky(WireEndpointsListResponse, arena_allocator, owned_body);
    return .{
        .arena = arena,
        .data = parsed.data,
    };
}

pub fn countQueryString(allocator: std.mem.Allocator, request: CountRequest) ![]u8 {
    return query_mod.build(allocator, &.{.{ .name = "output_modalities", .value = request.output_modalities }});
}

pub fn getPath(allocator: std.mem.Allocator, request: GetRequest) ![]u8 {
    var path: std.ArrayList(u8) = .empty;
    errdefer path.deinit(allocator);

    try path.appendSlice(allocator, "/model/");
    try appendPathSegment(allocator, &path, request.author);
    try path.append(allocator, '/');
    try appendPathSegment(allocator, &path, request.slug);

    return path.toOwnedSlice(allocator);
}

pub fn endpointsPath(allocator: std.mem.Allocator, request: EndpointsListRequest) ![]u8 {
    var path: std.ArrayList(u8) = .empty;
    errdefer path.deinit(allocator);

    try path.appendSlice(allocator, "/models/");
    try appendPathSegment(allocator, &path, request.author);
    try path.append(allocator, '/');
    try appendPathSegment(allocator, &path, request.slug);
    try path.appendSlice(allocator, "/endpoints");

    return path.toOwnedSlice(allocator);
}

fn appendPathSegment(allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: []const u8) !void {
    const hex = "0123456789ABCDEF";
    for (value) |byte| {
        if (std.ascii.isAlphanumeric(byte) or byte == '-' or byte == '_' or byte == '.' or byte == '~') {
            try output.append(allocator, byte);
        } else {
            try output.appendSlice(allocator, &.{ '%', hex[byte >> 4], hex[byte & 0x0F] });
        }
    }
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

test "models user list parses response and ignores unknown fields" {
    const body =
        \\{
        \\  "data": [
        \\    {
        \\      "id": "openai/gpt-4",
        \\      "name": "GPT-4",
        \\      "description": "User-visible model",
        \\      "context_length": 8192,
        \\      "pricing": {
        \\        "prompt": "0.00003",
        \\        "completion": "0.00006"
        \\      },
        \\      "unknown": true
        \\    }
        \\  ]
        \\}
    ;

    var result = try listUserWithTransport(std.testing.allocator, config_mod.Config{ .api_key = "test-key" }, http.FakeTransport{ .body = body }, .{});
    defer result.deinit();

    try std.testing.expectEqual(@as(usize, 1), result.data.len);
    try std.testing.expectEqualStrings("openai/gpt-4", result.data[0].id);
    try std.testing.expectEqualStrings("GPT-4", result.data[0].name.?);
    try std.testing.expectEqual(@as(?u32, 8192), result.data[0].context_length);
    try std.testing.expectEqualStrings("0.00003", result.data[0].pricing.?.prompt.?);
}

test "models user list sends GET /models/user" {
    var prepared = try http.prepareRequest(std.testing.allocator, .{ .api_key = "test-key" }, .{
        .method = .GET,
        .path = "/models/user",
    }, .{});
    defer prepared.deinit();

    try std.testing.expectEqual(std.http.Method.GET, prepared.method);
    try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/models/user", prepared.url);
}

test "models user list maps error status to ApiError" {
    try std.testing.expectError(error.ApiError, listUserWithTransport(
        std.testing.allocator,
        config_mod.Config{ .api_key = "test-key" },
        http.FakeTransport{ .status = .unauthorized, .body = "{\"error\":{\"message\":\"bad key\"}}" },
        .{},
    ));
}

test "models get parses response and ignores unknown fields" {
    const body =
        \\{
        \\  "data": {
        \\    "id": "openai/gpt-4o-mini",
        \\    "name": "GPT-4o mini",
        \\    "description": "Small model",
        \\    "context_length": 128000,
        \\    "pricing": {
        \\      "prompt": "0.00000015",
        \\      "completion": "0.0000006"
        \\    },
        \\    "unknown": true
        \\  }
        \\}
    ;

    var result = try getWithTransport(std.testing.allocator, config_mod.Config{ .api_key = "test-key" }, http.FakeTransport{ .body = body }, .{
        .author = "openai",
        .slug = "gpt-4o-mini",
    }, .{});
    defer result.deinit();

    try std.testing.expectEqualStrings("openai/gpt-4o-mini", result.data.id);
    try std.testing.expectEqualStrings("GPT-4o mini", result.data.name.?);
    try std.testing.expectEqual(@as(?u32, 128000), result.data.context_length);
    try std.testing.expectEqualStrings("0.00000015", result.data.pricing.?.prompt.?);
}

test "models get sends GET /model/{author}/{slug}" {
    const path = try getPath(std.testing.allocator, .{ .author = "openai", .slug = "gpt-4o-mini" });
    defer std.testing.allocator.free(path);

    var prepared = try http.prepareRequest(std.testing.allocator, .{ .api_key = "test-key" }, .{
        .method = .GET,
        .path = path,
    }, .{});
    defer prepared.deinit();

    try std.testing.expectEqual(std.http.Method.GET, prepared.method);
    try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/model/openai/gpt-4o-mini", prepared.url);
}

test "models get path escapes path segments" {
    const path = try getPath(std.testing.allocator, .{ .author = "author name", .slug = "model/slug:free" });
    defer std.testing.allocator.free(path);

    try std.testing.expectEqualStrings("/model/author%20name/model%2Fslug%3Afree", path);
}

test "models get maps error status to ApiError" {
    try std.testing.expectError(error.ApiError, getWithTransport(
        std.testing.allocator,
        config_mod.Config{ .api_key = "test-key" },
        http.FakeTransport{ .status = .not_found, .body = "{\"error\":{\"message\":\"not found\"}}" },
        .{ .author = "openai", .slug = "missing" },
        .{},
    ));
}

test "models endpoints list parses response and ignores unknown fields" {
    const body =
        \\{
        \\  "data": {
        \\    "id": "openai/gpt-4",
        \\    "name": "GPT-4",
        \\    "description": "GPT-4 endpoints",
        \\    "created": 1692901234,
        \\    "architecture": {
        \\      "input_modalities": ["text"],
        \\      "modality": "text->text",
        \\      "output_modalities": ["text"],
        \\      "tokenizer": "GPT"
        \\    },
        \\    "endpoints": [
        \\      {
        \\        "name": "GPT-4 on OpenAI",
        \\        "provider_name": "OpenAI",
        \\        "model_id": "openai/gpt-4",
        \\        "model_name": "GPT-4",
        \\        "context_length": 8192,
        \\        "max_completion_tokens": 4096,
        \\        "pricing": {
        \\          "prompt": "0.00003",
        \\          "completion": "0.00006"
        \\        },
        \\        "latency_last_30m": { "p50": 120, "p75": 150, "p90": 180, "p99": 250 },
        \\        "supported_parameters": ["temperature", "top_p"],
        \\        "supports_implicit_caching": true,
        \\        "tag": "default",
        \\        "unknown": true
        \\      }
        \\    ],
        \\    "unknown": true
        \\  }
        \\}
    ;

    var result = try listEndpointsWithTransport(std.testing.allocator, config_mod.Config{ .api_key = "test-key" }, http.FakeTransport{ .body = body }, .{
        .author = "openai",
        .slug = "gpt-4",
    }, .{});
    defer result.deinit();

    try std.testing.expectEqualStrings("openai/gpt-4", result.data.id);
    try std.testing.expectEqual(@as(i64, 1692901234), result.data.created);
    try std.testing.expectEqualStrings("text", result.data.architecture.input_modalities[0]);
    try std.testing.expectEqual(@as(usize, 1), result.data.endpoints.len);
    try std.testing.expectEqualStrings("GPT-4 on OpenAI", result.data.endpoints[0].name);
    try std.testing.expectEqualStrings("OpenAI", result.data.endpoints[0].provider_name);
    try std.testing.expectEqual(@as(u32, 8192), result.data.endpoints[0].context_length);
    try std.testing.expectEqualStrings("0.00003", result.data.endpoints[0].pricing.prompt.?);
    try std.testing.expectEqual(@as(?f64, 120), result.data.endpoints[0].latency_last_30m.?.p50);
    try std.testing.expect(result.data.endpoints[0].supports_implicit_caching);
    try std.testing.expectEqualStrings("default", result.data.endpoints[0].tag);
}

test "models endpoints list sends GET /models/{author}/{slug}/endpoints" {
    const path = try endpointsPath(std.testing.allocator, .{ .author = "openai", .slug = "gpt-4" });
    defer std.testing.allocator.free(path);

    var prepared = try http.prepareRequest(std.testing.allocator, .{ .api_key = "test-key" }, .{
        .method = .GET,
        .path = path,
    }, .{});
    defer prepared.deinit();

    try std.testing.expectEqual(std.http.Method.GET, prepared.method);
    try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/models/openai/gpt-4/endpoints", prepared.url);
}

test "models endpoints path escapes path segments" {
    const path = try endpointsPath(std.testing.allocator, .{ .author = "author name", .slug = "model/slug" });
    defer std.testing.allocator.free(path);

    try std.testing.expectEqualStrings("/models/author%20name/model%2Fslug/endpoints", path);
}

test "models endpoints list maps error status to ApiError" {
    try std.testing.expectError(error.ApiError, listEndpointsWithTransport(
        std.testing.allocator,
        config_mod.Config{ .api_key = "test-key" },
        http.FakeTransport{ .status = .not_found, .body = "{\"error\":{\"message\":\"not found\"}}" },
        .{ .author = "openai", .slug = "missing" },
        .{},
    ));
}

test "models count parses response and ignores unknown fields" {
    const body =
        \\{
        \\  "data": {
        \\    "count": 150,
        \\    "unknown": true
        \\  },
        \\  "unknown": true
        \\}
    ;

    var result = try countWithTransport(std.testing.allocator, config_mod.Config{ .api_key = "test-key" }, http.FakeTransport{ .body = body }, .{}, .{});
    defer result.deinit();

    try std.testing.expectEqual(@as(u64, 150), result.data.count);
}

test "models count sends GET /models/count without query" {
    const query = try countQueryString(std.testing.allocator, .{});
    defer std.testing.allocator.free(query);

    var prepared = try http.prepareRequest(std.testing.allocator, .{ .api_key = "test-key" }, .{
        .method = .GET,
        .path = "/models/count",
        .query = query,
    }, .{});
    defer prepared.deinit();

    try std.testing.expectEqual(std.http.Method.GET, prepared.method);
    try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/models/count", prepared.url);
}

test "models count sends escaped output modalities query" {
    const query = try countQueryString(std.testing.allocator, .{ .output_modalities = "text,image" });
    defer std.testing.allocator.free(query);

    var prepared = try http.prepareRequest(std.testing.allocator, .{ .api_key = "test-key" }, .{
        .method = .GET,
        .path = "/models/count",
        .query = query,
    }, .{});
    defer prepared.deinit();

    try std.testing.expectEqual(std.http.Method.GET, prepared.method);
    try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/models/count?output_modalities=text%2Cimage", prepared.url);
}

test "models count supports all output modalities" {
    const query = try countQueryString(std.testing.allocator, .{ .output_modalities = "all" });
    defer std.testing.allocator.free(query);

    try std.testing.expectEqualStrings("output_modalities=all", query);
}

test "models count maps error status to ApiError" {
    try std.testing.expectError(error.ApiError, countWithTransport(
        std.testing.allocator,
        config_mod.Config{ .api_key = "test-key" },
        http.FakeTransport{ .status = .bad_request, .body = "{\"error\":{\"message\":\"bad modalities\"}}" },
        .{},
        .{},
    ));
}
