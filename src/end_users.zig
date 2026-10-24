//! End-user management API.
//!
//! Returned fields and response metadata are owned by each response's arena
//! until `deinit`. User identifiers are passed unchanged; the service enforces
//! its documented 1..512-character, Unicode, NUL, and whitespace constraints.

const std = @import("std");

const config_mod = @import("config.zig");
const http = @import("http.zig");
const json = @import("json.zig");
const options_mod = @import("options.zig");
const query_mod = @import("query.zig");

pub const ListRequest = struct {
    offset: ?u64 = null,
    limit: ?u64 = null,
    user: ?[]const u8 = null,
    include_inactive: ?bool = null,
};

pub const CreateRequest = struct {
    user: []const u8,
};

pub const UpdateRequest = struct {
    is_active: bool,
};

pub const EndUser = struct {
    user: []const u8,
    is_active: bool,
    created_at: []const u8,
    updated_at: []const u8,
};

pub const ListResponse = struct {
    arena: std.heap.ArenaAllocator,
    data: []EndUser,
    total_count: f64,
    response_metadata: http.ResponseMetadata = .{},

    pub fn deinit(self: *ListResponse) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

fn DataResponse(comptime name: []const u8) type {
    _ = name;
    return struct {
        arena: std.heap.ArenaAllocator,
        data: EndUser,
        response_metadata: http.ResponseMetadata = .{},

        pub fn deinit(self: *@This()) void {
            self.arena.deinit();
            self.* = undefined;
        }
    };
}

pub const CreateResponse = DataResponse("CreateResponse");
pub const GetResponse = DataResponse("GetResponse");
pub const UpdateResponse = DataResponse("UpdateResponse");

/// DELETE is a soft deactivation operation. It is safe to repeat and does not
/// imply that the end-user record was removed.
pub const DeleteResponse = struct {
    arena: std.heap.ArenaAllocator,
    response_metadata: http.ResponseMetadata = .{},

    pub fn deinit(self: *DeleteResponse) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

const WireListResponse = struct {
    data: []EndUser,
    total_count: f64,
};
const WireDataResponse = struct { data: EndUser };

pub fn list(client: anytype, request: ListRequest, request_options: options_mod.RequestOptions) !ListResponse {
    return listWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, request, request_options);
}

pub fn listWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, request: ListRequest, request_options: options_mod.RequestOptions) !ListResponse {
    const query = try listQueryString(allocator, request);
    defer allocator.free(query);
    var response = try execute(allocator, config, transport, .{ .method = .GET, .path = "/external-users", .query = query }, request_options);
    defer response.deinit();
    return parseListResponse(allocator, response);
}

pub fn create(client: anytype, request: CreateRequest, request_options: options_mod.RequestOptions) !CreateResponse {
    return createWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, request, request_options);
}

pub fn createWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, request: CreateRequest, request_options: options_mod.RequestOptions) !CreateResponse {
    const body = try json.stringifyRequest(allocator, request);
    defer allocator.free(body);
    var response = try execute(allocator, config, transport, .{ .method = .POST, .path = "/external-users", .body = body }, request_options);
    defer response.deinit();
    return parseCreateResponse(allocator, response);
}

pub fn get(client: anytype, user: []const u8, request_options: options_mod.RequestOptions) !GetResponse {
    return getWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, user, request_options);
}

pub fn getWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, user: []const u8, request_options: options_mod.RequestOptions) !GetResponse {
    const path = try endUserPath(allocator, user);
    defer allocator.free(path);
    var response = try execute(allocator, config, transport, .{ .method = .GET, .path = path }, request_options);
    defer response.deinit();
    return parseGetResponse(allocator, response);
}

pub fn update(client: anytype, user: []const u8, request: UpdateRequest, request_options: options_mod.RequestOptions) !UpdateResponse {
    return updateWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, user, request, request_options);
}

pub fn updateWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, user: []const u8, request: UpdateRequest, request_options: options_mod.RequestOptions) !UpdateResponse {
    const body = try json.stringifyRequest(allocator, request);
    defer allocator.free(body);
    const path = try endUserPath(allocator, user);
    defer allocator.free(path);
    var response = try execute(allocator, config, transport, .{ .method = .PATCH, .path = path, .body = body }, request_options);
    defer response.deinit();
    return parseUpdateResponse(allocator, response);
}

pub fn delete(client: anytype, user: []const u8, request_options: options_mod.RequestOptions) !DeleteResponse {
    return deleteWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, user, request_options);
}

pub fn deleteWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, user: []const u8, request_options: options_mod.RequestOptions) !DeleteResponse {
    const path = try endUserPath(allocator, user);
    defer allocator.free(path);
    var response = try execute(allocator, config, transport, .{ .method = .DELETE, .path = path }, request_options);
    defer response.deinit();
    return parseDeleteResponse(allocator, response);
}

fn execute(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, request: http.HttpRequest, request_options: options_mod.RequestOptions) !http.HttpResponse {
    var prepared = try http.prepareRequest(allocator, config, request, request_options);
    defer prepared.deinit();
    return transport.execute(allocator, prepared);
}

pub fn parseListResponse(allocator: std.mem.Allocator, response: http.HttpResponse) !ListResponse {
    if (response.status != .ok) return error.ApiError;
    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const arena_allocator = arena.allocator();
    const parsed = try json.parseResponseLeaky(WireListResponse, arena_allocator, try arena_allocator.dupe(u8, response.body));
    const metadata = try http.ResponseMetadata.fromHttpResponse(arena_allocator, response);
    return .{ .arena = arena, .data = parsed.data, .total_count = parsed.total_count, .response_metadata = metadata };
}

pub fn parseCreateResponse(allocator: std.mem.Allocator, response: http.HttpResponse) !CreateResponse {
    if (response.status != .created) return error.ApiError;
    return parseDataResponse(CreateResponse, allocator, response);
}

pub fn parseGetResponse(allocator: std.mem.Allocator, response: http.HttpResponse) !GetResponse {
    if (response.status != .ok) return error.ApiError;
    return parseDataResponse(GetResponse, allocator, response);
}

pub fn parseUpdateResponse(allocator: std.mem.Allocator, response: http.HttpResponse) !UpdateResponse {
    if (response.status != .ok) return error.ApiError;
    return parseDataResponse(UpdateResponse, allocator, response);
}

fn parseDataResponse(comptime T: type, allocator: std.mem.Allocator, response: http.HttpResponse) !T {
    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const arena_allocator = arena.allocator();
    const parsed = try json.parseResponseLeaky(WireDataResponse, arena_allocator, try arena_allocator.dupe(u8, response.body));
    const metadata = try http.ResponseMetadata.fromHttpResponse(arena_allocator, response);
    return .{ .arena = arena, .data = parsed.data, .response_metadata = metadata };
}

pub fn parseDeleteResponse(allocator: std.mem.Allocator, response: http.HttpResponse) !DeleteResponse {
    if (response.status != .no_content) return error.ApiError;
    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const metadata = try http.ResponseMetadata.fromHttpResponse(arena.allocator(), response);
    return .{ .arena = arena, .response_metadata = metadata };
}

fn listQueryString(allocator: std.mem.Allocator, request: ListRequest) ![]u8 {
    const offset = if (request.offset) |value| try std.fmt.allocPrint(allocator, "{d}", .{value}) else null;
    defer if (offset) |value| allocator.free(value);
    const limit = if (request.limit) |value| try std.fmt.allocPrint(allocator, "{d}", .{value}) else null;
    defer if (limit) |value| allocator.free(value);
    return query_mod.build(allocator, &.{
        .{ .name = "offset", .value = offset },
        .{ .name = "limit", .value = limit },
        .{ .name = "user", .value = request.user },
        .{ .name = "include_inactive", .value = boolParam(request.include_inactive) },
    });
}

fn boolParam(value: ?bool) ?[]const u8 {
    return if (value) |present| if (present) "true" else "false" else null;
}

fn endUserPath(allocator: std.mem.Allocator, user: []const u8) ![]u8 {
    if (std.mem.eql(u8, user, ".") or std.mem.eql(u8, user, "..")) return error.InvalidUser;
    var path: std.ArrayList(u8) = .empty;
    errdefer path.deinit(allocator);
    try path.appendSlice(allocator, "/external-users/");
    try appendPathSegment(allocator, &path, user);
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

const user_json =
    \\{
    \\  "data": {
    \\    "user": "person/東京?x=1",
    \\    "is_active": false,
    \\    "created_at": "2026-01-01T00:00:00Z",
    \\    "updated_at": "2026-01-02T00:00:00Z",
    \\    "future_field": true
    \\  }
    \\}
;

test "end users list parses rich and empty responses, with owned metadata" {
    const body =
        \\{
        \\  "data": [{ "user": "alice", "is_active": true, "created_at": "created", "updated_at": "updated", "extra": 1 }],
        \\  "total_count": 1
        \\}
    ;
    var result = try listWithTransport(std.testing.allocator, .{ .api_key = "test-key" }, http.FakeTransport{ .body = body, .headers = &.{.{ .name = "X-Request-ID", .value = "req_end_user" }} }, .{}, .{});
    defer result.deinit();
    try std.testing.expectEqualStrings("alice", result.data[0].user);
    try std.testing.expectEqual(@as(f64, 1), result.total_count);
    try std.testing.expectEqualStrings("req_end_user", result.response_metadata.request_id.?);

    var empty = try listWithTransport(std.testing.allocator, .{ .api_key = "test-key" }, http.FakeTransport{ .body = "{\"data\":[],\"total_count\":0}" }, .{}, .{});
    defer empty.deinit();
    try std.testing.expectEqual(@as(usize, 0), empty.data.len);
}

test "end users list query includes requested fields and omits defaults" {
    const omitted = try listQueryString(std.testing.allocator, .{});
    defer std.testing.allocator.free(omitted);
    try std.testing.expectEqualStrings("", omitted);
    const query = try listQueryString(std.testing.allocator, .{ .offset = 0, .limit = 50, .user = "a.b", .include_inactive = false });
    defer std.testing.allocator.free(query);
    try std.testing.expectEqualStrings("offset=0&limit=50&user=a.b&include_inactive=false", query);
}

test "end users data operations parse required fields and retain false" {
    var created = try createWithTransport(std.testing.allocator, .{ .api_key = "test-key" }, http.FakeTransport{ .status = .created, .body = user_json }, .{ .user = "person/東京?x=1" }, .{});
    defer created.deinit();
    try std.testing.expectEqual(false, created.data.is_active);
    var got = try getWithTransport(std.testing.allocator, .{ .api_key = "test-key" }, http.FakeTransport{ .body = user_json }, "person/東京?x=1", .{});
    defer got.deinit();
    var updated = try updateWithTransport(std.testing.allocator, .{ .api_key = "test-key" }, http.FakeTransport{ .body = user_json }, "person/東京?x=1", .{ .is_active = false }, .{});
    defer updated.deinit();
    try std.testing.expectEqualStrings("2026-01-02T00:00:00Z", updated.data.updated_at);
    try std.testing.expectError(error.MissingField, getWithTransport(std.testing.allocator, .{ .api_key = "test-key" }, http.FakeTransport{ .body = "{\"data\":{\"user\":\"a\"}}" }, "a", .{}));
}

test "end users delete accepts empty 204 body and retains metadata" {
    var result = try deleteWithTransport(std.testing.allocator, .{ .api_key = "test-key" }, http.FakeTransport{ .status = .no_content, .headers = &.{.{ .name = "X-Request-ID", .value = "req_delete" }} }, "alice", .{});
    defer result.deinit();
    try std.testing.expectEqualStrings("req_delete", result.response_metadata.request_id.?);
}

test "end users map non-success statuses to ApiError for every operation" {
    try std.testing.expectError(error.ApiError, listWithTransport(std.testing.allocator, .{ .api_key = "test-key" }, http.FakeTransport{ .status = .unauthorized }, .{}, .{}));
    try std.testing.expectError(error.ApiError, createWithTransport(std.testing.allocator, .{ .api_key = "test-key" }, http.FakeTransport{ .status = .conflict }, .{ .user = "alice" }, .{}));
    try std.testing.expectError(error.ApiError, getWithTransport(std.testing.allocator, .{ .api_key = "test-key" }, http.FakeTransport{ .status = .not_found }, "alice", .{}));
    try std.testing.expectError(error.ApiError, updateWithTransport(std.testing.allocator, .{ .api_key = "test-key" }, http.FakeTransport{ .status = .internal_server_error }, "alice", .{ .is_active = true }, .{}));
    try std.testing.expectError(error.ApiError, deleteWithTransport(std.testing.allocator, .{ .api_key = "test-key" }, http.FakeTransport{}, "alice", .{}));
}

const CapturingTransport = struct {
    expected_method: std.http.Method,
    expected_url: []const u8,
    expected_body: ?[]const u8 = null,
    status: std.http.Status = .ok,
    body: []const u8 = user_json,

    pub fn execute(self: *const CapturingTransport, allocator: std.mem.Allocator, prepared: http.PreparedRequest) !http.HttpResponse {
        try std.testing.expectEqual(self.expected_method, prepared.method);
        try std.testing.expectEqualStrings(self.expected_url, prepared.url);
        if (self.expected_body) |expected| try std.testing.expectEqualStrings(expected, prepared.body.?);
        try std.testing.expectEqualStrings("test-header", headerValue(prepared.headers, "X-Test").?);
        const fake = http.FakeTransport{ .status = self.status, .body = self.body };
        return fake.execute(allocator, prepared);
    }
};

fn headerValue(headers: []const http.Header, name: []const u8) ?[]const u8 {
    for (headers) |header| if (std.ascii.eqlIgnoreCase(header.name, name)) return header.value;
    return null;
}

test "end user operations use external user paths and encode complete identifiers" {
    const encoded = "person%2F%E6%9D%B1%E4%BA%AC%3Fx%3D1";
    const options: options_mod.RequestOptions = .{ .extra_headers = &.{.{ .name = "X-Test", .value = "test-header" }} };
    const list_transport = CapturingTransport{ .expected_method = .GET, .expected_url = "https://openrouter.ai/api/v1/external-users?user=" ++ encoded, .body = "{\"data\":[],\"total_count\":0}" };
    var listed = try listWithTransport(std.testing.allocator, .{ .api_key = "test-key" }, &list_transport, .{ .user = "person/東京?x=1" }, options);
    defer listed.deinit();
    const create_transport = CapturingTransport{ .expected_method = .POST, .expected_url = "https://openrouter.ai/api/v1/external-users", .expected_body = "{\"user\":\"alice\"}", .status = .created };
    var created = try createWithTransport(std.testing.allocator, .{ .api_key = "test-key" }, &create_transport, .{ .user = "alice" }, options);
    defer created.deinit();
    const get_transport = CapturingTransport{ .expected_method = .GET, .expected_url = "https://openrouter.ai/api/v1/external-users/" ++ encoded };
    var got = try getWithTransport(std.testing.allocator, .{ .api_key = "test-key" }, &get_transport, "person/東京?x=1", options);
    defer got.deinit();
    const update_transport = CapturingTransport{ .expected_method = .PATCH, .expected_url = "https://openrouter.ai/api/v1/external-users/" ++ encoded, .expected_body = "{\"is_active\":false}" };
    var updated = try updateWithTransport(std.testing.allocator, .{ .api_key = "test-key" }, &update_transport, "person/東京?x=1", .{ .is_active = false }, options);
    defer updated.deinit();
    const delete_transport = CapturingTransport{ .expected_method = .DELETE, .expected_url = "https://openrouter.ai/api/v1/external-users/" ++ encoded, .status = .no_content, .body = "" };
    var deleted = try deleteWithTransport(std.testing.allocator, .{ .api_key = "test-key" }, &delete_transport, "person/東京?x=1", options);
    defer deleted.deinit();
    try std.testing.expectError(error.InvalidUser, getWithTransport(std.testing.allocator, .{ .api_key = "test-key" }, http.FakeTransport{}, ".", .{}));
    const query = try listQueryString(std.testing.allocator, .{ .user = "." });
    defer std.testing.allocator.free(query);
    try std.testing.expectEqualStrings("user=.", query);
}
