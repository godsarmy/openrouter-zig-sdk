//! Rerank API.

const std = @import("std");

const config_mod = @import("config.zig");
const errors = @import("errors.zig");
const http = @import("http.zig");
const json = @import("json.zig");
const options_mod = @import("options.zig");

pub const CreateRequest = struct {
    model: []const u8,
    query: []const u8,
    documents: []const []const u8,
    top_n: ?u32 = null,
    provider: ?std.json.Value = null,
};

pub const CreateResponse = struct {
    arena: std.heap.ArenaAllocator,
    id: ?[]const u8 = null,
    model: []const u8,
    provider: ?[]const u8 = null,
    results: []Result,
    usage: ?Usage = null,

    pub fn deinit(self: *CreateResponse) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

pub const Result = struct {
    document: Document,
    index: u32,
    relevance_score: f64,
};

pub const Document = struct {
    text: []const u8,
};

pub const Usage = struct {
    cost: ?f64 = null,
    search_units: ?u32 = null,
    total_tokens: ?u32 = null,
};

const WireCreateResponse = struct {
    id: ?[]const u8 = null,
    model: []const u8,
    provider: ?[]const u8 = null,
    results: []Result,
    usage: ?Usage = null,
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
        .path = "/rerank",
        .body = body,
    }, request_options);
    defer prepared.deinit();

    var response = try transport.execute(allocator, prepared);
    defer response.deinit();

    return parseCreateResponse(allocator, response);
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
        .id = parsed.id,
        .model = parsed.model,
        .provider = parsed.provider,
        .results = parsed.results,
        .usage = parsed.usage,
    };
}

test "rerank create serializes request" {
    const documents = &.{ "Paris is the capital of France.", "Berlin is the capital of Germany." };
    const body = try json.stringifyRequest(std.testing.allocator, CreateRequest{
        .model = "cohere/rerank-v3.5",
        .query = "What is the capital of France?",
        .documents = documents,
        .top_n = 1,
    });
    defer std.testing.allocator.free(body);

    try std.testing.expect(std.mem.indexOf(u8, body, "\"model\":\"cohere/rerank-v3.5\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"query\":\"What is the capital of France?\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"top_n\":1") != null);
}

test "rerank create parses response and ignores unknown fields" {
    const body =
        \\{
        \\  "id": "rerank_123",
        \\  "model": "cohere/rerank-v3.5",
        \\  "provider": "Cohere",
        \\  "results": [
        \\    {
        \\      "document": { "text": "Paris is the capital of France." },
        \\      "index": 0,
        \\      "relevance_score": 0.98,
        \\      "unknown": true
        \\    }
        \\  ],
        \\  "usage": { "cost": 0, "search_units": 1, "total_tokens": 150 },
        \\  "unknown": true
        \\}
    ;

    var result = try createWithTransport(std.testing.allocator, config_mod.Config{ .api_key = "test-key" }, http.FakeTransport{ .body = body }, .{
        .model = "cohere/rerank-v3.5",
        .query = "What is the capital of France?",
        .documents = &.{ "Paris is the capital of France.", "Berlin is the capital of Germany." },
    }, .{});
    defer result.deinit();

    try std.testing.expectEqualStrings("rerank_123", result.id.?);
    try std.testing.expectEqualStrings("cohere/rerank-v3.5", result.model);
    try std.testing.expectEqual(@as(usize, 1), result.results.len);
    try std.testing.expectEqual(@as(u32, 0), result.results[0].index);
    try std.testing.expectEqualStrings("Paris is the capital of France.", result.results[0].document.text);
    try std.testing.expectApproxEqAbs(@as(f64, 0.98), result.results[0].relevance_score, 0.00001);
    try std.testing.expectEqual(@as(?u32, 150), result.usage.?.total_tokens);
}

test "rerank create parses response without id" {
    const body =
        \\{
        \\  "model": "cohere/rerank-v3.5",
        \\  "results": [
        \\    {
        \\      "document": { "text": "Paris is the capital of France." },
        \\      "index": 0,
        \\      "relevance_score": 0.98
        \\    }
        \\  ]
        \\}
    ;

    var result = try createWithTransport(std.testing.allocator, config_mod.Config{ .api_key = "test-key" }, http.FakeTransport{ .body = body }, .{
        .model = "cohere/rerank-v3.5",
        .query = "What is the capital of France?",
        .documents = &.{"Paris is the capital of France."},
    }, .{});
    defer result.deinit();

    try std.testing.expectEqual(@as(?[]const u8, null), result.id);
    try std.testing.expectEqualStrings("cohere/rerank-v3.5", result.model);
    try std.testing.expectEqual(@as(usize, 1), result.results.len);
}

test "rerank create sends POST /rerank" {
    const body = try json.stringifyRequest(std.testing.allocator, CreateRequest{
        .model = "cohere/rerank-v3.5",
        .query = "query",
        .documents = &.{"doc"},
    });
    defer std.testing.allocator.free(body);

    var prepared = try http.prepareRequest(std.testing.allocator, .{ .api_key = "test-key" }, .{
        .method = .POST,
        .path = "/rerank",
        .body = body,
    }, .{});
    defer prepared.deinit();

    try std.testing.expectEqual(std.http.Method.POST, prepared.method);
    try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/rerank", prepared.url);
    try std.testing.expectEqualStrings(body, prepared.body.?);
}

test "rerank create maps error status to ApiError" {
    try std.testing.expectError(error.ApiError, createWithTransport(
        std.testing.allocator,
        config_mod.Config{ .api_key = "test-key" },
        http.FakeTransport{ .status = .bad_request, .body = "{\"error\":{\"message\":\"bad request\"}}" },
        .{ .model = "cohere/rerank-v3.5", .query = "query", .documents = &.{"doc"} },
        .{},
    ));
}
