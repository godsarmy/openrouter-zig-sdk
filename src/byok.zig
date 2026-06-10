//! Bring Your Own Key (BYOK) management API.

const std = @import("std");

const config_mod = @import("config.zig");
const errors = @import("errors.zig");
const http = @import("http.zig");
const json = @import("json.zig");
const options_mod = @import("options.zig");
const query_mod = @import("query.zig");

pub const ListRequest = struct {
    offset: ?i64 = null,
    limit: ?i64 = null,
    workspace_id: ?[]const u8 = null,
    provider: ?[]const u8 = null,
};

pub const StringList = union(enum) {
    null_value,
    values: []const []const u8,

    pub fn jsonStringify(self: StringList, jws: anytype) !void {
        switch (self) {
            .null_value => try jws.write(null),
            .values => |value| try jws.write(value),
        }
    }
};

pub const CreateRequest = struct {
    key: []const u8,
    provider: []const u8,
    name: ?[]const u8 = null,
    workspace_id: ?[]const u8 = null,
    disabled: ?bool = null,
    is_fallback: ?bool = null,
    allowed_models: ?StringList = null,
    allowed_user_ids: ?StringList = null,
};

pub const UpdateRequest = struct {
    name: ?[]const u8 = null,
    disabled: ?bool = null,
    is_fallback: ?bool = null,
    key: ?[]const u8 = null,
    allowed_models: ?StringList = null,
    allowed_user_ids: ?StringList = null,
};

pub const ByokKey = struct {
    id: ?[]const u8 = null,
    provider: ?[]const u8 = null,
    workspace_id: ?[]const u8 = null,
    label: ?[]const u8 = null,
    name: ?[]const u8 = null,
    created_at: ?[]const u8 = null,
    updated_at: ?[]const u8 = null,
    disabled: ?bool = null,
    is_fallback: ?bool = null,
    sort_order: ?i64 = null,
    allowed_models: ?[]const []const u8 = null,
    allowed_user_ids: ?[]const []const u8 = null,
    allowed_api_key_hashes: ?[]const []const u8 = null,
};

pub const ListResponse = struct {
    arena: std.heap.ArenaAllocator,
    data: []ByokKey,
    total_count: ?i64 = null,

    pub fn deinit(self: *ListResponse) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

pub const CreateResponse = struct {
    arena: std.heap.ArenaAllocator,
    data: ByokKey,

    pub fn deinit(self: *CreateResponse) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

pub const GetResponse = struct {
    arena: std.heap.ArenaAllocator,
    data: ByokKey,

    pub fn deinit(self: *GetResponse) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

pub const UpdateResponse = struct {
    arena: std.heap.ArenaAllocator,
    data: ByokKey,

    pub fn deinit(self: *UpdateResponse) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

pub const DeleteResponse = struct {
    arena: std.heap.ArenaAllocator,
    deleted: bool,

    pub fn deinit(self: *DeleteResponse) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

const WireListResponse = struct { data: []ByokKey, total_count: ?i64 = null };
const WireCreateResponse = struct { data: ByokKey };
const WireGetResponse = struct { data: ByokKey };
const WireUpdateResponse = struct { data: ByokKey };
const WireDeleteResponse = struct { deleted: bool };

pub fn list(client: anytype, request: ListRequest, request_options: options_mod.RequestOptions) !ListResponse {
    return listWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, request, request_options);
}

pub fn listWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, request: ListRequest, request_options: options_mod.RequestOptions) !ListResponse {
    const query = try listQueryString(allocator, request);
    defer allocator.free(query);
    var prepared = try http.prepareRequest(allocator, config, .{ .method = .GET, .path = "/byok", .query = query }, request_options);
    defer prepared.deinit();
    var response = try transport.execute(allocator, prepared);
    defer response.deinit();
    return parseListResponse(allocator, response);
}

pub fn create(client: anytype, request: CreateRequest, request_options: options_mod.RequestOptions) !CreateResponse {
    return createWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, request, request_options);
}

pub fn createWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, request: CreateRequest, request_options: options_mod.RequestOptions) !CreateResponse {
    const body = try json.stringifyRequest(allocator, request);
    defer allocator.free(body);
    var prepared = try http.prepareRequest(allocator, config, .{ .method = .POST, .path = "/byok", .body = body }, request_options);
    defer prepared.deinit();
    var response = try transport.execute(allocator, prepared);
    defer response.deinit();
    return parseCreateResponse(allocator, response);
}

pub fn get(client: anytype, id: []const u8, request_options: options_mod.RequestOptions) !GetResponse {
    return getWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, id, request_options);
}

pub fn getWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, id: []const u8, request_options: options_mod.RequestOptions) !GetResponse {
    const path = try std.fmt.allocPrint(allocator, "/byok/{s}", .{id});
    defer allocator.free(path);
    var prepared = try http.prepareRequest(allocator, config, .{ .method = .GET, .path = path }, request_options);
    defer prepared.deinit();
    var response = try transport.execute(allocator, prepared);
    defer response.deinit();
    return parseGetResponse(allocator, response);
}

pub fn update(client: anytype, id: []const u8, request: UpdateRequest, request_options: options_mod.RequestOptions) !UpdateResponse {
    return updateWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, id, request, request_options);
}

pub fn updateWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, id: []const u8, request: UpdateRequest, request_options: options_mod.RequestOptions) !UpdateResponse {
    const body = try json.stringifyRequest(allocator, request);
    defer allocator.free(body);
    const path = try std.fmt.allocPrint(allocator, "/byok/{s}", .{id});
    defer allocator.free(path);
    var prepared = try http.prepareRequest(allocator, config, .{ .method = .PATCH, .path = path, .body = body }, request_options);
    defer prepared.deinit();
    var response = try transport.execute(allocator, prepared);
    defer response.deinit();
    return parseUpdateResponse(allocator, response);
}

pub fn delete(client: anytype, id: []const u8, request_options: options_mod.RequestOptions) !DeleteResponse {
    return deleteWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, id, request_options);
}

pub fn deleteWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, id: []const u8, request_options: options_mod.RequestOptions) !DeleteResponse {
    const path = try std.fmt.allocPrint(allocator, "/byok/{s}", .{id});
    defer allocator.free(path);
    var prepared = try http.prepareRequest(allocator, config, .{ .method = .DELETE, .path = path }, request_options);
    defer prepared.deinit();
    var response = try transport.execute(allocator, prepared);
    defer response.deinit();
    return parseDeleteResponse(allocator, response);
}

pub fn parseListResponse(allocator: std.mem.Allocator, response: http.HttpResponse) !ListResponse {
    if (errors.isErrorStatus(@intFromEnum(response.status))) return error.ApiError;
    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const parsed = try json.parseResponseLeaky(WireListResponse, arena.allocator(), try arena.allocator().dupe(u8, response.body));
    return .{ .arena = arena, .data = parsed.data, .total_count = parsed.total_count };
}

pub fn parseCreateResponse(allocator: std.mem.Allocator, response: http.HttpResponse) !CreateResponse {
    if (response.status != .created and errors.isErrorStatus(@intFromEnum(response.status))) return error.ApiError;
    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const parsed = try json.parseResponseLeaky(WireCreateResponse, arena.allocator(), try arena.allocator().dupe(u8, response.body));
    return .{ .arena = arena, .data = parsed.data };
}

pub fn parseGetResponse(allocator: std.mem.Allocator, response: http.HttpResponse) !GetResponse {
    if (errors.isErrorStatus(@intFromEnum(response.status))) return error.ApiError;
    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const parsed = try json.parseResponseLeaky(WireGetResponse, arena.allocator(), try arena.allocator().dupe(u8, response.body));
    return .{ .arena = arena, .data = parsed.data };
}

pub fn parseUpdateResponse(allocator: std.mem.Allocator, response: http.HttpResponse) !UpdateResponse {
    if (errors.isErrorStatus(@intFromEnum(response.status))) return error.ApiError;
    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const parsed = try json.parseResponseLeaky(WireUpdateResponse, arena.allocator(), try arena.allocator().dupe(u8, response.body));
    return .{ .arena = arena, .data = parsed.data };
}

pub fn parseDeleteResponse(allocator: std.mem.Allocator, response: http.HttpResponse) !DeleteResponse {
    if (errors.isErrorStatus(@intFromEnum(response.status))) return error.ApiError;
    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const parsed = try json.parseResponseLeaky(WireDeleteResponse, arena.allocator(), try arena.allocator().dupe(u8, response.body));
    return .{ .arena = arena, .deleted = parsed.deleted };
}

fn listQueryString(allocator: std.mem.Allocator, request: ListRequest) ![]u8 {
    const offset_str = if (request.offset) |value| try std.fmt.allocPrint(allocator, "{d}", .{value}) else null;
    defer if (offset_str) |value| allocator.free(value);
    const limit_str = if (request.limit) |value| try std.fmt.allocPrint(allocator, "{d}", .{value}) else null;
    defer if (limit_str) |value| allocator.free(value);
    return query_mod.build(allocator, &.{
        .{ .name = "offset", .value = offset_str },
        .{ .name = "limit", .value = limit_str },
        .{ .name = "workspace_id", .value = request.workspace_id },
        .{ .name = "provider", .value = request.provider },
    });
}

test "byok list serializes query params" {
    const query = try listQueryString(std.testing.allocator, .{ .offset = 10, .limit = 25, .workspace_id = "ws_123", .provider = "openai" });
    defer std.testing.allocator.free(query);
    try std.testing.expectEqualStrings("offset=10&limit=25&workspace_id=ws_123&provider=openai", query);
}

test "byok create serializes request" {
    const body = try json.stringifyRequest(std.testing.allocator, CreateRequest{
        .key = "sk-provider",
        .provider = "openai",
        .name = "Production OpenAI Key",
        .disabled = false,
        .is_fallback = true,
        .allowed_models = .{ .values = &.{"openai/gpt-4o"} },
    });
    defer std.testing.allocator.free(body);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"key\":\"sk-provider\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"provider\":\"openai\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"allowed_models\":[\"openai/gpt-4o\"]") != null);
}

test "byok update can serialize nullable allow lists" {
    const body = try json.stringifyRequest(std.testing.allocator, UpdateRequest{ .allowed_models = .null_value, .allowed_user_ids = .{ .values = &.{"user_123"} } });
    defer std.testing.allocator.free(body);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"allowed_models\":null") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"allowed_user_ids\":[\"user_123\"]") != null);
}

test "byok list parses response" {
    const body =
        \\{"data":[{"id":"byok_123","provider":"openai","workspace_id":"ws_123","label":"sk-...abc","name":"Production","created_at":"2026-06-09T00:00:00Z","disabled":false,"is_fallback":true,"sort_order":1,"allowed_models":["openai/gpt-4o"],"allowed_user_ids":null,"allowed_api_key_hashes":null,"unknown":true}],"total_count":1}
    ;
    var result = try listWithTransport(std.testing.allocator, .{ .api_key = "test-key" }, http.FakeTransport{ .body = body }, .{}, .{});
    defer result.deinit();
    try std.testing.expectEqual(@as(usize, 1), result.data.len);
    try std.testing.expectEqual(@as(?i64, 1), result.total_count);
    try std.testing.expectEqualStrings("byok_123", result.data[0].id.?);
    try std.testing.expectEqualStrings("openai/gpt-4o", result.data[0].allowed_models.?[0]);
}

test "byok create sends POST /byok" {
    const body = try json.stringifyRequest(std.testing.allocator, CreateRequest{ .key = "sk-provider", .provider = "openai" });
    defer std.testing.allocator.free(body);
    var prepared = try http.prepareRequest(std.testing.allocator, .{ .api_key = "test-key" }, .{ .method = .POST, .path = "/byok", .body = body }, .{});
    defer prepared.deinit();
    try std.testing.expectEqual(std.http.Method.POST, prepared.method);
    try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/byok", prepared.url);
    try std.testing.expectEqualStrings(body, prepared.body.?);
}

test "byok get sends GET /byok/id" {
    var prepared = try http.prepareRequest(std.testing.allocator, .{ .api_key = "test-key" }, .{ .method = .GET, .path = "/byok/byok_123" }, .{});
    defer prepared.deinit();
    try std.testing.expectEqual(std.http.Method.GET, prepared.method);
    try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/byok/byok_123", prepared.url);
}

test "byok update sends PATCH /byok/id" {
    const body = try json.stringifyRequest(std.testing.allocator, UpdateRequest{ .name = "Updated" });
    defer std.testing.allocator.free(body);
    var prepared = try http.prepareRequest(std.testing.allocator, .{ .api_key = "test-key" }, .{ .method = .PATCH, .path = "/byok/byok_123", .body = body }, .{});
    defer prepared.deinit();
    try std.testing.expectEqual(std.http.Method.PATCH, prepared.method);
    try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/byok/byok_123", prepared.url);
    try std.testing.expectEqualStrings(body, prepared.body.?);
}

test "byok delete sends DELETE /byok/id" {
    var prepared = try http.prepareRequest(std.testing.allocator, .{ .api_key = "test-key" }, .{ .method = .DELETE, .path = "/byok/byok_123" }, .{});
    defer prepared.deinit();
    try std.testing.expectEqual(std.http.Method.DELETE, prepared.method);
    try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/byok/byok_123", prepared.url);
}

test "byok create parses response" {
    var result = try createWithTransport(std.testing.allocator, .{ .api_key = "test-key" }, http.FakeTransport{ .status = .created, .body = "{\"data\":{\"id\":\"byok_123\",\"provider\":\"openai\",\"label\":\"sk-...abc\",\"disabled\":false}}" }, .{ .key = "sk-provider", .provider = "openai" }, .{});
    defer result.deinit();
    try std.testing.expectEqualStrings("byok_123", result.data.id.?);
}

test "byok get parses response" {
    var result = try getWithTransport(std.testing.allocator, .{ .api_key = "test-key" }, http.FakeTransport{ .body = "{\"data\":{\"id\":\"byok_123\",\"provider\":\"openai\",\"label\":\"sk-...abc\"}}" }, "byok_123", .{});
    defer result.deinit();
    try std.testing.expectEqualStrings("openai", result.data.provider.?);
}

test "byok update parses response" {
    var result = try updateWithTransport(std.testing.allocator, .{ .api_key = "test-key" }, http.FakeTransport{ .body = "{\"data\":{\"id\":\"byok_123\",\"provider\":\"openai\",\"name\":\"Updated\"}}" }, "byok_123", .{ .name = "Updated" }, .{});
    defer result.deinit();
    try std.testing.expectEqualStrings("Updated", result.data.name.?);
}

test "byok delete parses response" {
    var result = try deleteWithTransport(std.testing.allocator, .{ .api_key = "test-key" }, http.FakeTransport{ .body = "{\"deleted\":true}" }, "byok_123", .{});
    defer result.deinit();
    try std.testing.expect(result.deleted);
}

test "byok error status maps to ApiError" {
    try std.testing.expectError(error.ApiError, listWithTransport(
        std.testing.allocator,
        .{ .api_key = "test-key" },
        http.FakeTransport{ .status = .unauthorized, .body = "{\"error\":{\"message\":\"unauthorized\"}}" },
        .{},
        .{},
    ));
}
