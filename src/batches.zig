//! Batch API. Returned values, including JSON values and response metadata, are owned until `deinit`.

const std = @import("std");
const config_mod = @import("config.zig");
const errors = @import("errors.zig");
const http = @import("http.zig");
const json = @import("json.zig");
const options_mod = @import("options.zig");
const query = @import("query.zig");

pub const Endpoint = enum {
    @"/v1/chat/completions",
    @"/v1/responses",
    @"/v1/messages",
    @"/v1/embeddings",
};

pub const FilterStatus = enum { validating, in_progress, completed, failed, expired, cancelled };

/// Workspace-scoped batch listing filters. Unset values are not sent.
pub const ListRequest = struct {
    limit: ?u64 = null,
    after: ?[]const u8 = null,
    status: ?[]const FilterStatus = null,
    created_after: ?[]const u8 = null,
    created_before: ?[]const u8 = null,
};

pub const Provider = struct {
    only: ?[]const []const u8 = null,
    allow_fallbacks: ?bool = null,
};

pub const BatchInput = struct {
    custom_id: []const u8,
    /// Must be a JSON object for the selected endpoint.
    body: std.json.Value,
};

pub const CreateRequest = struct {
    endpoint: Endpoint,
    model: []const u8,
    requests: []const BatchInput,
    completion_window: ?[]const u8 = null,
    provider: ?Provider = null,
};

pub const RequestCounts = struct { total: u64, completed: u64, failed: u64 };

pub const Usage = struct {
    prompt_tokens: u64,
    completion_tokens: u64,
    total_tokens: u64,
    cost: ?f64,
    is_byok: ?bool,
    service_tier: ?[]const u8,
    speed: ?[]const u8,
    cost_details: ?std.json.Value,
    prompt_tokens_details: ?std.json.Value,
    completion_tokens_details: ?std.json.Value,
    cache_creation: ?std.json.Value,
    iterations: ?std.json.Value,
    server_tool_use: ?std.json.Value,
};

pub const ResultResponse = struct {
    status_code: u32,
    request_id: ?[]const u8,
    body: std.json.Value,
};

pub const ResultError = struct {
    type: []const u8,
    message: []const u8,
    param: ?[]const u8,
    error_type: ?[]const u8 = null,
};

pub const Result = struct {
    id: []const u8,
    custom_id: []const u8,
    response: ?ResultResponse,
    @"error": ?ResultError,
};

pub const BatchObject = struct {
    id: []const u8,
    object: []const u8,
    endpoint: []const u8,
    model: []const u8,
    completion_window: []const u8,
    status: []const u8,
    created_at: i64,
    finalized_at: ?i64,
    request_counts: RequestCounts,
    usage: ?Usage,
    results: ?[]Result,
    @"error": ?struct { message: []const u8 },
    provider: ?[]const u8 = null,
    expires_at: ?i64 = null,
};

pub const ListEnvelope = struct {
    object: []const u8,
    data: []BatchObject,
    first_id: ?[]const u8,
    last_id: ?[]const u8,
    has_more: bool,
};

pub const DeletionUpstream = struct { provider: []const u8, status: []const u8 };
pub const Deletion = struct { openrouter: []const u8, upstream: ?DeletionUpstream = null };
pub const DeleteObject = struct { id: []const u8, object: []const u8, deletion: Deletion };

pub const BatchResponse = struct {
    arena: std.heap.ArenaAllocator,
    data: BatchObject,
    response_metadata: http.ResponseMetadata,
    pub fn deinit(self: *BatchResponse) void {
        self.arena.deinit();
        self.* = undefined;
    }
};
pub const ListResponse = struct {
    arena: std.heap.ArenaAllocator,
    data: ListEnvelope,
    response_metadata: http.ResponseMetadata,
    pub fn deinit(self: *ListResponse) void {
        self.arena.deinit();
        self.* = undefined;
    }
};
pub const DeleteResponse = struct {
    arena: std.heap.ArenaAllocator,
    data: DeleteObject,
    response_metadata: http.ResponseMetadata,
    pub fn deinit(self: *DeleteResponse) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

pub fn list(client: anytype, request: ListRequest, request_options: options_mod.RequestOptions) !ListResponse {
    return listWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, request, request_options);
}
pub fn create(client: anytype, request: CreateRequest, request_options: options_mod.RequestOptions) !BatchResponse {
    return createWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, request, request_options);
}
pub fn get(client: anytype, id: []const u8, request_options: options_mod.RequestOptions) !BatchResponse {
    return getWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, id, request_options);
}
pub fn delete(client: anytype, id: []const u8, request_options: options_mod.RequestOptions) !DeleteResponse {
    return deleteWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, id, request_options);
}

pub fn listWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, request: ListRequest, request_options: options_mod.RequestOptions) !ListResponse {
    const text = try listQueryString(allocator, request);
    defer allocator.free(text);
    var prepared = try http.prepareRequest(allocator, config, .{ .method = .GET, .path = "/batches", .query = text }, request_options);
    defer prepared.deinit();
    var response = try transport.execute(allocator, prepared);
    defer response.deinit();
    return parseListResponse(allocator, response);
}
pub fn createWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, request: CreateRequest, request_options: options_mod.RequestOptions) !BatchResponse {
    try validateCreate(request);
    const body = try json.stringifyRequest(allocator, request);
    defer allocator.free(body);
    var prepared = try http.prepareRequest(allocator, config, .{ .method = .POST, .path = "/batches", .body = body }, request_options);
    defer prepared.deinit();
    var response = try transport.execute(allocator, prepared);
    defer response.deinit();
    return parseBatchResponse(allocator, response, .accepted);
}
pub fn getWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, id: []const u8, request_options: options_mod.RequestOptions) !BatchResponse {
    const path = try batchPath(allocator, id);
    defer allocator.free(path);
    var prepared = try http.prepareRequest(allocator, config, .{ .method = .GET, .path = path }, request_options);
    defer prepared.deinit();
    var response = try transport.execute(allocator, prepared);
    defer response.deinit();
    return parseBatchResponse(allocator, response, .ok);
}
pub fn deleteWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, id: []const u8, request_options: options_mod.RequestOptions) !DeleteResponse {
    const path = try batchPath(allocator, id);
    defer allocator.free(path);
    var prepared = try http.prepareRequest(allocator, config, .{ .method = .DELETE, .path = path }, request_options);
    defer prepared.deinit();
    var response = try transport.execute(allocator, prepared);
    defer response.deinit();
    return parseDeleteResponse(allocator, response);
}

pub fn parseBatchResponse(allocator: std.mem.Allocator, response: http.HttpResponse, expected: std.http.Status) !BatchResponse {
    if (response.status != expected) return error.ApiError;
    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const a = arena.allocator();
    const data = try json.parseResponseLeaky(BatchObject, a, try a.dupe(u8, response.body));
    return .{ .arena = arena, .data = data, .response_metadata = try http.ResponseMetadata.fromHttpResponse(a, response) };
}
pub fn parseListResponse(allocator: std.mem.Allocator, response: http.HttpResponse) !ListResponse {
    if (response.status != .ok) return error.ApiError;
    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const a = arena.allocator();
    const data = try json.parseResponseLeaky(ListEnvelope, a, try a.dupe(u8, response.body));
    return .{ .arena = arena, .data = data, .response_metadata = try http.ResponseMetadata.fromHttpResponse(a, response) };
}
pub fn parseDeleteResponse(allocator: std.mem.Allocator, response: http.HttpResponse) !DeleteResponse {
    if (response.status != .ok) return error.ApiError;
    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const a = arena.allocator();
    const data = try json.parseResponseLeaky(DeleteObject, a, try a.dupe(u8, response.body));
    return .{ .arena = arena, .data = data, .response_metadata = try http.ResponseMetadata.fromHttpResponse(a, response) };
}

pub fn listQueryString(allocator: std.mem.Allocator, request: ListRequest) ![]u8 {
    const limit = if (request.limit) |value| try std.fmt.allocPrint(allocator, "{d}", .{value}) else null;
    defer if (limit) |value| allocator.free(value);
    var params: std.ArrayList(query.Param) = .empty;
    defer params.deinit(allocator);
    try params.append(allocator, .{ .name = "limit", .value = limit });
    try params.append(allocator, .{ .name = "after", .value = request.after });
    for (request.status orelse &.{}) |status| try params.append(allocator, .{ .name = "status", .value = @tagName(status) });
    try params.append(allocator, .{ .name = "created_after", .value = request.created_after });
    try params.append(allocator, .{ .name = "created_before", .value = request.created_before });
    return query.build(allocator, params.items);
}

fn validateCreate(request: CreateRequest) !void {
    if (request.model.len == 0) return error.InvalidRequest;
    for (request.requests) |item| if (item.body != .object) return error.InvalidRequest;
}
fn batchPath(allocator: std.mem.Allocator, id: []const u8) ![]u8 {
    if (std.mem.eql(u8, id, ".") or std.mem.eql(u8, id, "..")) return error.InvalidBatchId;
    const encoded = try encodeSegment(allocator, id);
    defer allocator.free(encoded);
    return std.fmt.allocPrint(allocator, "/batches/{s}", .{encoded});
}
fn encodeSegment(allocator: std.mem.Allocator, value: []const u8) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    const hex = "0123456789ABCDEF";
    for (value) |byte| {
        if (std.ascii.isAlphanumeric(byte) or byte == '-' or byte == '_' or byte == '.' or byte == '~') try out.append(allocator, byte) else try out.appendSlice(allocator, &.{ '%', hex[byte >> 4], hex[byte & 15] });
    }
    return out.toOwnedSlice(allocator);
}

test "batches create sends POST JSON and parses accepted batch" {
    const body =
        \\{"id":"batch_1","object":"batch","endpoint":"/v1/chat/completions","model":"openai/gpt-4o","completion_window":"24h","status":"validating","created_at":1,"finalized_at":null,"request_counts":{"total":1,"completed":0,"failed":0},"usage":null,"results":null,"error":null}
    ;
    var input_arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer input_arena.deinit();
    const input_body = try std.json.parseFromSliceLeaky(std.json.Value, input_arena.allocator(), "{\"messages\":[]}", .{});
    var result = try createWithTransport(std.testing.allocator, .{ .api_key = "test" }, http.FakeTransport{ .status = .accepted, .body = body }, .{ .endpoint = .@"/v1/chat/completions", .model = "openai/gpt-4o", .requests = &.{.{ .custom_id = "one", .body = input_body }}, .provider = .{ .allow_fallbacks = false, .only = &.{"openai"} } }, .{});
    defer result.deinit();
    try std.testing.expectEqualStrings("batch_1", result.data.id);
    try std.testing.expect(result.data.finalized_at == null);
}

test "batches list repeats status and omits defaults" {
    const all = try listQueryString(std.testing.allocator, .{ .after = "a/b?", .status = &.{ .validating, .completed }, .created_after = "2026-01-01T00:00:00Z" });
    defer std.testing.allocator.free(all);
    try std.testing.expectEqualStrings("after=a%2Fb%3F&status=validating&status=completed&created_after=2026-01-01T00%3A00%3A00Z", all);
    const empty = try listQueryString(std.testing.allocator, .{});
    defer std.testing.allocator.free(empty);
    try std.testing.expectEqualStrings("", empty);
}

test "batches prepare all four exact methods paths and create body" {
    const path = try batchPath(std.testing.allocator, "batch/a b");
    defer std.testing.allocator.free(path);
    try std.testing.expectEqualStrings("/batches/batch%2Fa%20b", path);

    var input_arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer input_arena.deinit();
    const input = try std.json.parseFromSliceLeaky(std.json.Value, input_arena.allocator(), "{\"input\":{\"x\":1}}", .{});
    const body = try json.stringifyRequest(std.testing.allocator, CreateRequest{
        .endpoint = .@"/v1/responses",
        .model = "m",
        .requests = &.{.{ .custom_id = "c", .body = input }},
        .provider = .{ .allow_fallbacks = false, .only = &.{"openai"} },
    });
    defer std.testing.allocator.free(body);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"allow_fallbacks\":false") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"input\":{\"x\":1}") != null);

    var list_prepared = try http.prepareRequest(std.testing.allocator, .{ .api_key = "test" }, .{ .method = .GET, .path = "/batches" }, .{});
    defer list_prepared.deinit();
    var create_prepared = try http.prepareRequest(std.testing.allocator, .{ .api_key = "test" }, .{ .method = .POST, .path = "/batches", .body = body }, .{});
    defer create_prepared.deinit();
    var get_prepared = try http.prepareRequest(std.testing.allocator, .{ .api_key = "test" }, .{ .method = .GET, .path = path }, .{});
    defer get_prepared.deinit();
    var delete_prepared = try http.prepareRequest(std.testing.allocator, .{ .api_key = "test" }, .{ .method = .DELETE, .path = path }, .{});
    defer delete_prepared.deinit();
    try std.testing.expectEqual(std.http.Method.GET, list_prepared.method);
    try std.testing.expectEqual(std.http.Method.POST, create_prepared.method);
    try std.testing.expectEqual(std.http.Method.GET, get_prepared.method);
    try std.testing.expectEqual(std.http.Method.DELETE, delete_prepared.method);
    try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/batches/batch%2Fa%20b", delete_prepared.url);
}

test "batches get parses native results usage and metadata" {
    const body =
        \\{"id":"b","object":"batch","endpoint":"/v1/responses","model":"m","completion_window":"24h","status":"completed","created_at":1,"finalized_at":2,"request_counts":{"total":2,"completed":1,"failed":1},"usage":{"prompt_tokens":1,"completion_tokens":2,"total_tokens":3,"cost":null,"is_byok":false,"service_tier":null,"speed":null,"cost_details":{"x":1},"prompt_tokens_details":null,"completion_tokens_details":null,"cache_creation":null,"iterations":null,"server_tool_use":null},"results":[{"id":"r","custom_id":"ok","response":{"status_code":200,"request_id":null,"body":{"output":[1]}},"error":null},{"id":"e","custom_id":"bad","response":null,"error":{"type":"invalid","message":"no","param":null}}],"error":null}
    ;
    var result = try getWithTransport(std.testing.allocator, .{ .api_key = "test" }, http.FakeTransport{ .body = body, .headers = &.{.{ .name = "X-Request-ID", .value = "req" }} }, "a/b c", .{});
    defer result.deinit();
    try std.testing.expectEqual(@as(usize, 2), result.data.results.?.len);
    try std.testing.expectEqualStrings("req", result.response_metadata.request_id.?);
}

test "batches delete parses both upstream forms and exact statuses" {
    const with_upstream = "{\"id\":\"b\",\"object\":\"batch.deleted\",\"deletion\":{\"openrouter\":\"deleted\",\"upstream\":{\"provider\":\"x\",\"status\":\"deleted\"}}}";
    var result = try deleteWithTransport(std.testing.allocator, .{ .api_key = "test" }, http.FakeTransport{ .body = with_upstream }, "a/b", .{});
    defer result.deinit();
    try std.testing.expectEqualStrings("x", result.data.deletion.upstream.?.provider);
    try std.testing.expectError(error.ApiError, deleteWithTransport(std.testing.allocator, .{ .api_key = "test" }, http.FakeTransport{ .status = .conflict }, "b", .{}));
}

test "batches map nonexact success and documented errors to ApiError" {
    try std.testing.expectError(error.ApiError, createWithTransport(std.testing.allocator, .{ .api_key = "test" }, http.FakeTransport{ .body = "{}" }, .{ .endpoint = .@"/v1/embeddings", .model = "m", .requests = &.{} }, .{}));
    for ([_]std.http.Status{ .payment_required, .gone }) |status| try std.testing.expectError(error.ApiError, getWithTransport(std.testing.allocator, .{ .api_key = "test" }, http.FakeTransport{ .status = status }, "b", .{}));
}

test "batches reject missing required nullable field and non-object request body" {
    const missing = "{\"id\":\"b\",\"object\":\"batch\",\"endpoint\":\"x\",\"model\":\"m\",\"completion_window\":\"24h\",\"status\":\"x\",\"created_at\":1,\"request_counts\":{\"total\":0,\"completed\":0,\"failed\":0},\"usage\":null,\"results\":null,\"error\":null}";
    try std.testing.expectError(error.MissingField, getWithTransport(std.testing.allocator, .{ .api_key = "test" }, http.FakeTransport{ .body = missing }, "b", .{}));
    try std.testing.expectError(error.InvalidRequest, createWithTransport(std.testing.allocator, .{ .api_key = "test" }, http.FakeTransport{}, .{ .endpoint = .@"/v1/messages", .model = "m", .requests = &.{.{ .custom_id = "x", .body = .{ .string = "bad" } }} }, .{}));
}

test "batches reject dot batch IDs for get and delete" {
    for ([_][]const u8{ ".", ".." }) |id| {
        try std.testing.expectError(error.InvalidBatchId, getWithTransport(std.testing.allocator, .{ .api_key = "test" }, http.FakeTransport{}, id, .{}));
        try std.testing.expectError(error.InvalidBatchId, deleteWithTransport(std.testing.allocator, .{ .api_key = "test" }, http.FakeTransport{}, id, .{}));
    }
}
