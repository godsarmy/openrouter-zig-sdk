//! Embeddings API.

const std = @import("std");

const chat = @import("chat.zig");
const config_mod = @import("config.zig");
const errors = @import("errors.zig");
const http = @import("http.zig");
const json = @import("json.zig");
const models_mod = @import("models.zig");
const options_mod = @import("options.zig");

pub const CreateRequest = struct {
    model: []const u8,
    input: Input,
};

pub const Input = union(enum) {
    string: []const u8,
    strings: []const []const u8,

    pub fn jsonStringify(self: Input, jws: anytype) !void {
        switch (self) {
            .string => |value| try jws.write(value),
            .strings => |value| try jws.write(value),
        }
    }
};

pub const CreateResponse = struct {
    arena: std.heap.ArenaAllocator,
    response_metadata: http.ResponseMetadata = .{},
    data: []Embedding,
    model: []const u8,
    usage: ?chat.Usage = null,

    pub fn deinit(self: *CreateResponse) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

pub const ModelsListResponse = models_mod.ListResponse;

pub const Embedding = struct {
    index: u32,
    embedding: []f32,
};

const WireCreateResponse = struct {
    data: []Embedding,
    model: []const u8,
    usage: ?chat.Usage = null,
};

pub fn create(client: anytype, request: CreateRequest, request_options: options_mod.RequestOptions) !CreateResponse {
    return createWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, request, request_options);
}

pub fn createWithTransport(
    allocator: std.mem.Allocator,
    config: config_mod.Config,
    transport: anytype,
    request: CreateRequest,
    request_options: options_mod.RequestOptions,
) !CreateResponse {
    const body = try json.stringifyRequest(allocator, request);
    defer allocator.free(body);

    var prepared = try http.prepareRequest(allocator, config, .{
        .method = .POST,
        .path = "/embeddings",
        .body = body,
    }, request_options);
    defer prepared.deinit();

    var response = try transport.execute(allocator, prepared);
    defer response.deinit();

    return parseCreateResponse(allocator, response);
}

pub fn listModels(client: anytype, request_options: options_mod.RequestOptions) !ModelsListResponse {
    return listModelsWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, request_options);
}

pub fn listModelsWithTransport(
    allocator: std.mem.Allocator,
    config: config_mod.Config,
    transport: anytype,
    request_options: options_mod.RequestOptions,
) !ModelsListResponse {
    var prepared = try http.prepareRequest(allocator, config, .{
        .method = .GET,
        .path = "/embeddings/models",
    }, request_options);
    defer prepared.deinit();

    var response = try transport.execute(allocator, prepared);
    defer response.deinit();

    return models_mod.parseListResponse(allocator, response);
}

pub fn parseCreateResponse(allocator: std.mem.Allocator, response: http.HttpResponse) !CreateResponse {
    if (errors.isErrorStatus(@intFromEnum(response.status))) return error.ApiError;

    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const arena_allocator = arena.allocator();

    const owned_body = try arena_allocator.dupe(u8, response.body);
    const parsed = try json.parseResponseLeaky(WireCreateResponse, arena_allocator, owned_body);
    return .{
        .arena = arena,
        .response_metadata = try http.ResponseMetadata.fromHttpResponse(arena_allocator, response),
        .data = parsed.data,
        .model = parsed.model,
        .usage = parsed.usage,
    };
}

test "embeddings request serializes single input string" {
    const body = try json.stringifyRequest(std.testing.allocator, CreateRequest{
        .model = "openai/text-embedding-3-small",
        .input = .{ .string = "Hello from Zig." },
    });
    defer std.testing.allocator.free(body);

    try std.testing.expect(std.mem.indexOf(u8, body, "\"model\":\"openai/text-embedding-3-small\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"input\":\"Hello from Zig.\"") != null);
}

test "embeddings request serializes multiple input strings" {
    const inputs = &.{ "Hello", "Zig" };
    const body = try json.stringifyRequest(std.testing.allocator, CreateRequest{
        .model = "openai/text-embedding-3-small",
        .input = .{ .strings = inputs },
    });
    defer std.testing.allocator.free(body);

    try std.testing.expect(std.mem.indexOf(u8, body, "\"input\":[\"Hello\",\"Zig\"]") != null);
}

test "embeddings create parses response" {
    const response_body =
        \\{
        \\  "object": "list",
        \\  "model": "openai/text-embedding-3-small",
        \\  "data": [
        \\    { "object": "embedding", "index": 0, "embedding": [0.1, -0.2, 0.3] },
        \\    { "object": "embedding", "index": 1, "embedding": [0.4, 0.5] }
        \\  ],
        \\  "usage": { "prompt_tokens": 4, "total_tokens": 4 }
        \\}
    ;

    var result = try createWithTransport(std.testing.allocator, .{ .api_key = "test-key" }, http.FakeTransport{ .body = response_body }, .{
        .model = "openai/text-embedding-3-small",
        .input = .{ .strings = &.{ "Hello", "Zig" } },
    }, .{});
    defer result.deinit();

    try std.testing.expectEqualStrings("openai/text-embedding-3-small", result.model);
    try std.testing.expectEqual(@as(usize, 2), result.data.len);
    try std.testing.expectEqual(@as(u32, 0), result.data[0].index);
    try std.testing.expectEqual(@as(usize, 3), result.data[0].embedding.len);
    try std.testing.expectApproxEqAbs(@as(f32, 0.1), result.data[0].embedding[0], 0.00001);
    try std.testing.expectApproxEqAbs(@as(f32, -0.2), result.data[0].embedding[1], 0.00001);
    try std.testing.expectEqual(@as(?u32, 4), result.usage.?.total_tokens);
}

test "embeddings create sends POST /embeddings" {
    const body = try json.stringifyRequest(std.testing.allocator, CreateRequest{
        .model = "openai/text-embedding-3-small",
        .input = .{ .string = "Hello" },
    });
    defer std.testing.allocator.free(body);

    var prepared = try http.prepareRequest(std.testing.allocator, .{ .api_key = "test-key" }, .{
        .method = .POST,
        .path = "/embeddings",
        .body = body,
    }, .{});
    defer prepared.deinit();

    try std.testing.expectEqual(std.http.Method.POST, prepared.method);
    try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/embeddings", prepared.url);
    try std.testing.expectEqualStrings(body, prepared.body.?);
}

test "embeddings create maps error status to ApiError" {
    try std.testing.expectError(error.ApiError, createWithTransport(
        std.testing.allocator,
        .{ .api_key = "test-key" },
        http.FakeTransport{ .status = .bad_request, .body = "{\"error\":{\"message\":\"bad input\"}}" },
        .{ .model = "openai/text-embedding-3-small", .input = .{ .string = "Hello" } },
        .{},
    ));
}

test "embeddings models list parses response and ignores unknown fields" {
    const response_body =
        \\{
        \\  "data": [
        \\    {
        \\      "id": "openai/text-embedding-3-small",
        \\      "name": "Text Embedding 3 Small",
        \\      "context_length": 8191,
        \\      "pricing": {
        \\        "prompt": "0.00000002"
        \\      },
        \\      "unknown": true
        \\    }
        \\  ]
        \\}
    ;

    var result = try listModelsWithTransport(std.testing.allocator, .{ .api_key = "test-key" }, http.FakeTransport{ .body = response_body }, .{});
    defer result.deinit();

    try std.testing.expectEqual(@as(usize, 1), result.data.len);
    try std.testing.expectEqualStrings("openai/text-embedding-3-small", result.data[0].id);
    try std.testing.expectEqualStrings("Text Embedding 3 Small", result.data[0].name.?);
    try std.testing.expectEqual(@as(?u32, 8191), result.data[0].context_length);
    try std.testing.expectEqualStrings("0.00000002", result.data[0].pricing.?.prompt.?);
}

test "embeddings models list sends GET /embeddings/models" {
    var prepared = try http.prepareRequest(std.testing.allocator, .{ .api_key = "test-key" }, .{
        .method = .GET,
        .path = "/embeddings/models",
    }, .{});
    defer prepared.deinit();

    try std.testing.expectEqual(std.http.Method.GET, prepared.method);
    try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/embeddings/models", prepared.url);
}

test "embeddings models list maps error status to ApiError" {
    try std.testing.expectError(error.ApiError, listModelsWithTransport(
        std.testing.allocator,
        .{ .api_key = "test-key" },
        http.FakeTransport{ .status = .unauthorized, .body = "{\"error\":{\"message\":\"bad key\"}}" },
        .{},
    ));
}
