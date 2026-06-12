//! Workspaces management API.

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
};

pub const CreateRequest = struct {
    name: []const u8,
    slug: []const u8,
    description: ?[]const u8 = null,
    default_text_model: ?[]const u8 = null,
    default_image_model: ?[]const u8 = null,
    default_provider_sort: ?[]const u8 = null,
    is_observability_io_logging_enabled: ?bool = null,
    is_observability_broadcast_enabled: ?bool = null,
    is_data_discount_logging_enabled: ?bool = null,
    io_logging_sampling_rate: ?f64 = null,
    io_logging_api_key_ids: ?[]const []const u8 = null,
};

pub const UpdateRequest = struct {
    name: ?[]const u8 = null,
    slug: ?[]const u8 = null,
    description: ?[]const u8 = null,
    default_text_model: ?[]const u8 = null,
    default_image_model: ?[]const u8 = null,
    default_provider_sort: ?[]const u8 = null,
    is_observability_io_logging_enabled: ?bool = null,
    is_observability_broadcast_enabled: ?bool = null,
    is_data_discount_logging_enabled: ?bool = null,
    io_logging_sampling_rate: ?f64 = null,
    io_logging_api_key_ids: ?[]const []const u8 = null,
};

pub const BulkMembersRequest = struct {
    user_ids: []const []const u8,
};

pub const Workspace = struct {
    id: ?[]const u8 = null,
    name: ?[]const u8 = null,
    slug: ?[]const u8 = null,
    description: ?[]const u8 = null,
    created_at: ?[]const u8 = null,
    created_by: ?[]const u8 = null,
    updated_at: ?[]const u8 = null,
    default_text_model: ?[]const u8 = null,
    default_image_model: ?[]const u8 = null,
    default_provider_sort: ?[]const u8 = null,
    is_observability_io_logging_enabled: ?bool = null,
    is_observability_broadcast_enabled: ?bool = null,
    is_data_discount_logging_enabled: ?bool = null,
    io_logging_sampling_rate: ?f64 = null,
    io_logging_api_key_ids: ?[]const []const u8 = null,
};

pub const WorkspaceMember = struct {
    id: ?[]const u8 = null,
    workspace_id: ?[]const u8 = null,
    user_id: ?[]const u8 = null,
    role: ?[]const u8 = null,
    created_at: ?[]const u8 = null,
};

pub const ListResponse = responseWithList(Workspace);
pub const CreateResponse = responseWithData(Workspace);
pub const GetResponse = responseWithData(Workspace);
pub const UpdateResponse = responseWithData(Workspace);

pub const DeleteResponse = struct {
    arena: std.heap.ArenaAllocator,
    deleted: bool,

    pub fn deinit(self: *DeleteResponse) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

pub const BulkAddMembersResponse = struct {
    arena: std.heap.ArenaAllocator,
    added_count: ?i64 = null,
    data: []WorkspaceMember = &.{},

    pub fn deinit(self: *BulkAddMembersResponse) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

pub const BulkRemoveMembersResponse = struct {
    arena: std.heap.ArenaAllocator,
    removed_count: ?i64 = null,

    pub fn deinit(self: *BulkRemoveMembersResponse) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

fn responseWithData(comptime T: type) type {
    return struct {
        arena: std.heap.ArenaAllocator,
        data: T,

        pub fn deinit(self: *@This()) void {
            self.arena.deinit();
            self.* = undefined;
        }
    };
}

fn responseWithList(comptime T: type) type {
    return struct {
        arena: std.heap.ArenaAllocator,
        data: []T,
        total_count: ?i64 = null,

        pub fn deinit(self: *@This()) void {
            self.arena.deinit();
            self.* = undefined;
        }
    };
}

const WireListResponse = struct { data: []Workspace, total_count: ?i64 = null };
const WireDataResponse = struct { data: Workspace };
const WireDeleteResponse = struct { deleted: bool };
const WireBulkAddMembersResponse = struct { added_count: ?i64 = null, data: []WorkspaceMember = &.{} };
const WireBulkRemoveMembersResponse = struct { removed_count: ?i64 = null };

pub fn list(client: anytype, request: ListRequest, request_options: options_mod.RequestOptions) !ListResponse {
    return listWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, request, request_options);
}

pub fn listWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, request: ListRequest, request_options: options_mod.RequestOptions) !ListResponse {
    const query = try listQueryString(allocator, request);
    defer allocator.free(query);
    var response = try execute(allocator, config, transport, .{ .method = .GET, .path = "/workspaces", .query = query }, request_options);
    defer response.deinit();
    return parseListResponse(allocator, response);
}

pub fn create(client: anytype, request: CreateRequest, request_options: options_mod.RequestOptions) !CreateResponse {
    return createWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, request, request_options);
}

pub fn createWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, request: CreateRequest, request_options: options_mod.RequestOptions) !CreateResponse {
    const body = try json.stringifyRequest(allocator, request);
    defer allocator.free(body);
    var response = try execute(allocator, config, transport, .{ .method = .POST, .path = "/workspaces", .body = body }, request_options);
    defer response.deinit();
    return parseCreateResponse(allocator, response);
}

pub fn get(client: anytype, id: []const u8, request_options: options_mod.RequestOptions) !GetResponse {
    return getWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, id, request_options);
}

pub fn getWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, id: []const u8, request_options: options_mod.RequestOptions) !GetResponse {
    const path = try workspacePath(allocator, id, "");
    defer allocator.free(path);
    var response = try execute(allocator, config, transport, .{ .method = .GET, .path = path }, request_options);
    defer response.deinit();
    return parseGetResponse(allocator, response);
}

pub fn update(client: anytype, id: []const u8, request: UpdateRequest, request_options: options_mod.RequestOptions) !UpdateResponse {
    return updateWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, id, request, request_options);
}

pub fn updateWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, id: []const u8, request: UpdateRequest, request_options: options_mod.RequestOptions) !UpdateResponse {
    const body = try json.stringifyRequest(allocator, request);
    defer allocator.free(body);
    const path = try workspacePath(allocator, id, "");
    defer allocator.free(path);
    var response = try execute(allocator, config, transport, .{ .method = .PATCH, .path = path, .body = body }, request_options);
    defer response.deinit();
    return parseUpdateResponse(allocator, response);
}

pub fn delete(client: anytype, id: []const u8, request_options: options_mod.RequestOptions) !DeleteResponse {
    return deleteWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, id, request_options);
}

pub fn deleteWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, id: []const u8, request_options: options_mod.RequestOptions) !DeleteResponse {
    const path = try workspacePath(allocator, id, "");
    defer allocator.free(path);
    var response = try execute(allocator, config, transport, .{ .method = .DELETE, .path = path }, request_options);
    defer response.deinit();
    return parseDeleteResponse(allocator, response);
}

pub fn bulkAddMembers(client: anytype, id: []const u8, request: BulkMembersRequest, request_options: options_mod.RequestOptions) !BulkAddMembersResponse {
    return bulkAddMembersWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, id, request, request_options);
}

pub fn bulkAddMembersWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, id: []const u8, request: BulkMembersRequest, request_options: options_mod.RequestOptions) !BulkAddMembersResponse {
    const body = try json.stringifyRequest(allocator, request);
    defer allocator.free(body);
    const path = try workspacePath(allocator, id, "/members/add");
    defer allocator.free(path);
    var response = try execute(allocator, config, transport, .{ .method = .POST, .path = path, .body = body }, request_options);
    defer response.deinit();
    return parseBulkAddMembersResponse(allocator, response);
}

pub fn bulkRemoveMembers(client: anytype, id: []const u8, request: BulkMembersRequest, request_options: options_mod.RequestOptions) !BulkRemoveMembersResponse {
    return bulkRemoveMembersWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, id, request, request_options);
}

pub fn bulkRemoveMembersWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, id: []const u8, request: BulkMembersRequest, request_options: options_mod.RequestOptions) !BulkRemoveMembersResponse {
    const body = try json.stringifyRequest(allocator, request);
    defer allocator.free(body);
    const path = try workspacePath(allocator, id, "/members/remove");
    defer allocator.free(path);
    var response = try execute(allocator, config, transport, .{ .method = .POST, .path = path, .body = body }, request_options);
    defer response.deinit();
    return parseBulkRemoveMembersResponse(allocator, response);
}

fn execute(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, request: http.HttpRequest, request_options: options_mod.RequestOptions) !http.HttpResponse {
    var prepared = try http.prepareRequest(allocator, config, request, request_options);
    defer prepared.deinit();
    return try transport.execute(allocator, prepared);
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
    return parseDataResponse(CreateResponse, allocator, response);
}

pub fn parseGetResponse(allocator: std.mem.Allocator, response: http.HttpResponse) !GetResponse {
    return parseDataResponse(GetResponse, allocator, response);
}

pub fn parseUpdateResponse(allocator: std.mem.Allocator, response: http.HttpResponse) !UpdateResponse {
    return parseDataResponse(UpdateResponse, allocator, response);
}

fn parseDataResponse(comptime T: type, allocator: std.mem.Allocator, response: http.HttpResponse) !T {
    if (errors.isErrorStatus(@intFromEnum(response.status))) return error.ApiError;
    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const parsed = try json.parseResponseLeaky(WireDataResponse, arena.allocator(), try arena.allocator().dupe(u8, response.body));
    return .{ .arena = arena, .data = parsed.data };
}

pub fn parseDeleteResponse(allocator: std.mem.Allocator, response: http.HttpResponse) !DeleteResponse {
    if (errors.isErrorStatus(@intFromEnum(response.status))) return error.ApiError;
    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const parsed = try json.parseResponseLeaky(WireDeleteResponse, arena.allocator(), try arena.allocator().dupe(u8, response.body));
    return .{ .arena = arena, .deleted = parsed.deleted };
}

pub fn parseBulkAddMembersResponse(allocator: std.mem.Allocator, response: http.HttpResponse) !BulkAddMembersResponse {
    if (errors.isErrorStatus(@intFromEnum(response.status))) return error.ApiError;
    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const parsed = try json.parseResponseLeaky(WireBulkAddMembersResponse, arena.allocator(), try arena.allocator().dupe(u8, response.body));
    return .{ .arena = arena, .added_count = parsed.added_count, .data = parsed.data };
}

pub fn parseBulkRemoveMembersResponse(allocator: std.mem.Allocator, response: http.HttpResponse) !BulkRemoveMembersResponse {
    if (errors.isErrorStatus(@intFromEnum(response.status))) return error.ApiError;
    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const parsed = try json.parseResponseLeaky(WireBulkRemoveMembersResponse, arena.allocator(), try arena.allocator().dupe(u8, response.body));
    return .{ .arena = arena, .removed_count = parsed.removed_count };
}

fn listQueryString(allocator: std.mem.Allocator, request: ListRequest) ![]u8 {
    const offset_str = if (request.offset) |value| try std.fmt.allocPrint(allocator, "{d}", .{value}) else null;
    defer if (offset_str) |value| allocator.free(value);
    const limit_str = if (request.limit) |value| try std.fmt.allocPrint(allocator, "{d}", .{value}) else null;
    defer if (limit_str) |value| allocator.free(value);
    return query_mod.build(allocator, &.{
        .{ .name = "offset", .value = offset_str },
        .{ .name = "limit", .value = limit_str },
    });
}

fn workspacePath(allocator: std.mem.Allocator, id: []const u8, suffix: []const u8) ![]u8 {
    return std.fmt.allocPrint(allocator, "/workspaces/{s}{s}", .{ id, suffix });
}

test "workspaces list serializes query params" {
    const query = try listQueryString(std.testing.allocator, .{ .offset = 1, .limit = 20 });
    defer std.testing.allocator.free(query);
    try std.testing.expectEqualStrings("offset=1&limit=20", query);
}

test "workspaces create serializes request" {
    const body = try json.stringifyRequest(std.testing.allocator, CreateRequest{ .name = "Team", .slug = "team", .description = "Test" });
    defer std.testing.allocator.free(body);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"name\":\"Team\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"slug\":\"team\"") != null);
}

test "workspaces list parses response" {
    var result = try listWithTransport(std.testing.allocator, .{ .api_key = "test-key" }, http.FakeTransport{ .body = "{\"data\":[{\"id\":\"ws_123\",\"name\":\"Team\",\"slug\":\"team\"}],\"total_count\":1}" }, .{}, .{});
    defer result.deinit();
    try std.testing.expectEqual(@as(usize, 1), result.data.len);
    try std.testing.expectEqualStrings("ws_123", result.data[0].id.?);
}

test "workspaces create get update delete parse responses" {
    var created = try createWithTransport(std.testing.allocator, .{ .api_key = "test-key" }, http.FakeTransport{ .status = .created, .body = "{\"data\":{\"id\":\"ws_123\",\"name\":\"Team\",\"slug\":\"team\"}}" }, .{ .name = "Team", .slug = "team" }, .{});
    defer created.deinit();
    try std.testing.expectEqualStrings("team", created.data.slug.?);

    var got = try getWithTransport(std.testing.allocator, .{ .api_key = "test-key" }, http.FakeTransport{ .body = "{\"data\":{\"id\":\"ws_123\",\"name\":\"Team\"}}" }, "ws_123", .{});
    defer got.deinit();
    try std.testing.expectEqualStrings("Team", got.data.name.?);

    var updated = try updateWithTransport(std.testing.allocator, .{ .api_key = "test-key" }, http.FakeTransport{ .body = "{\"data\":{\"id\":\"ws_123\",\"name\":\"Updated\"}}" }, "ws_123", .{ .name = "Updated" }, .{});
    defer updated.deinit();
    try std.testing.expectEqualStrings("Updated", updated.data.name.?);

    var deleted = try deleteWithTransport(std.testing.allocator, .{ .api_key = "test-key" }, http.FakeTransport{ .body = "{\"deleted\":true}" }, "ws_123", .{});
    defer deleted.deinit();
    try std.testing.expect(deleted.deleted);
}

test "workspaces member bulk endpoints parse responses" {
    var added = try bulkAddMembersWithTransport(std.testing.allocator, .{ .api_key = "test-key" }, http.FakeTransport{ .body = "{\"added_count\":1,\"data\":[{\"id\":\"mem_1\",\"workspace_id\":\"ws_123\",\"user_id\":\"user_1\",\"role\":\"member\"}]}" }, "ws_123", .{ .user_ids = &.{"user_1"} }, .{});
    defer added.deinit();
    try std.testing.expectEqual(@as(?i64, 1), added.added_count);
    try std.testing.expectEqualStrings("user_1", added.data[0].user_id.?);

    var removed = try bulkRemoveMembersWithTransport(std.testing.allocator, .{ .api_key = "test-key" }, http.FakeTransport{ .body = "{\"removed_count\":1}" }, "ws_123", .{ .user_ids = &.{"user_1"} }, .{});
    defer removed.deinit();
    try std.testing.expectEqual(@as(?i64, 1), removed.removed_count);
}

test "workspaces paths and errors" {
    const path = try workspacePath(std.testing.allocator, "ws_123", "/members/add");
    defer std.testing.allocator.free(path);
    try std.testing.expectEqualStrings("/workspaces/ws_123/members/add", path);
    try std.testing.expectError(error.ApiError, listWithTransport(std.testing.allocator, .{ .api_key = "test-key" }, http.FakeTransport{ .status = .forbidden, .body = "{}" }, .{}, .{}));
}
