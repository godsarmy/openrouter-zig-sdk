//! SCIM directory management. Requires a management API key.
//! Responses own all data and metadata until `deinit`. Sync creation queues work;
//! poll `getSyncJob` explicitly until the returned status is terminal.
const std = @import("std");
const config_mod = @import("config.zig");
const http = @import("http.zig");
const json = @import("json.zig");
const options_mod = @import("options.zig");
const query = @import("query.zig");

pub const Role = enum { admin, member };
pub const CreateMappingRequest = struct { scim_group_id: []const u8, workspace_id: []const u8, role: Role };
pub const UpdateMappingRequest = struct { role: Role };
pub const ListMappingsRequest = struct { offset: ?u64 = null, limit: ?u64 = null };
pub const ListGroupsRequest = struct { offset: ?u64 = null, limit: ?u64 = null, display_name: ?[]const u8 = null, external_id: ?[]const u8 = null };
/// false removes memberships granted by this mapping; true keeps them.
pub const DeleteMappingRequest = struct { keep_members: bool };
pub const Group = struct {
    created_at: []const u8,
    display_name: []const u8,
    external_id: ?[]const u8,
    id: []const u8,
    organization_id: []const u8,
    updated_at: []const u8,
};
pub const GroupMapping = struct {
    created_at: []const u8,
    id: []const u8,
    organization_id: []const u8,
    /// Preserves future server roles.
    role: []const u8,
    scim_group_id: []const u8,
    updated_at: []const u8,
    workspace_id: []const u8,
};
pub const SyncJob = struct {
    created_at: []const u8,
    deleted_groups: ?u64,
    error_message: ?[]const u8,
    finished_at: ?[]const u8,
    id: []const u8,
    started_at: ?[]const u8,
    /// Known values: queued, running, succeeded, failed; preserves future values.
    status: []const u8,
    synced_groups: ?u64,
};
pub const ListMappingsResponse = struct {
    arena: std.heap.ArenaAllocator,
    data: []GroupMapping,
    total_count: u64,
    response_metadata: http.ResponseMetadata,
    pub fn deinit(self: *@This()) void {
        self.arena.deinit();
        self.* = undefined;
    }
};
pub const ListGroupsResponse = struct {
    arena: std.heap.ArenaAllocator,
    data: []Group,
    total_count: u64,
    response_metadata: http.ResponseMetadata,
    pub fn deinit(self: *@This()) void {
        self.arena.deinit();
        self.* = undefined;
    }
};
pub const MappingResponse = struct {
    arena: std.heap.ArenaAllocator,
    data: GroupMapping,
    response_metadata: http.ResponseMetadata,
    pub fn deinit(self: *@This()) void {
        self.arena.deinit();
        self.* = undefined;
    }
};
pub const SyncJobResponse = struct {
    arena: std.heap.ArenaAllocator,
    data: SyncJob,
    response_metadata: http.ResponseMetadata,
    pub fn deinit(self: *@This()) void {
        self.arena.deinit();
        self.* = undefined;
    }
};
pub const DeleteMappingResponse = struct {
    arena: std.heap.ArenaAllocator,
    deleted: bool,
    response_metadata: http.ResponseMetadata,
    pub fn deinit(self: *@This()) void {
        self.arena.deinit();
        self.* = undefined;
    }
};
pub fn listMappings(client: anytype, request: ListMappingsRequest, request_options: options_mod.RequestOptions) !ListMappingsResponse {
    return listMappingsWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, request, request_options);
}
pub fn listMappingsWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, request: ListMappingsRequest, request_options: options_mod.RequestOptions) !ListMappingsResponse {
    const path = "/scim/group-mappings";
    var offset_buffer: [20]u8 = undefined;
    var limit_buffer: [20]u8 = undefined;
    const params = try query.build(allocator, &.{
        .{ .name = "offset", .value = if (request.offset) |v| try std.fmt.bufPrint(&offset_buffer, "{d}", .{v}) else null },
        .{ .name = "limit", .value = if (request.limit) |v| try std.fmt.bufPrint(&limit_buffer, "{d}", .{v}) else null },
    });
    defer allocator.free(params);
    const body: ?[]const u8 = null;
    return execute(ListMappingsResponse, allocator, config, transport, .{ .method = .GET, .path = path, .query = params, .body = body }, request_options);
}
pub fn listGroups(client: anytype, request: ListGroupsRequest, request_options: options_mod.RequestOptions) !ListGroupsResponse {
    return listGroupsWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, request, request_options);
}
pub fn listGroupsWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, request: ListGroupsRequest, request_options: options_mod.RequestOptions) !ListGroupsResponse {
    const path = "/scim/groups";
    var offset_buffer: [20]u8 = undefined;
    var limit_buffer: [20]u8 = undefined;
    const params = try query.build(allocator, &.{
        .{ .name = "offset", .value = if (request.offset) |v| try std.fmt.bufPrint(&offset_buffer, "{d}", .{v}) else null },
        .{ .name = "limit", .value = if (request.limit) |v| try std.fmt.bufPrint(&limit_buffer, "{d}", .{v}) else null },
        .{ .name = "display_name", .value = request.display_name },
        .{ .name = "external_id", .value = request.external_id },
    });
    defer allocator.free(params);
    const body: ?[]const u8 = null;
    return execute(ListGroupsResponse, allocator, config, transport, .{ .method = .GET, .path = path, .query = params, .body = body }, request_options);
}
pub fn createMapping(client: anytype, request: CreateMappingRequest, request_options: options_mod.RequestOptions) !MappingResponse {
    return createMappingWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, request, request_options);
}
pub fn createMappingWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, request: CreateMappingRequest, request_options: options_mod.RequestOptions) !MappingResponse {
    const path = "/scim/group-mappings";
    const params: ?[]const u8 = null;
    const body = try json.stringifyRequest(allocator, request);
    defer allocator.free(body);
    return execute(MappingResponse, allocator, config, transport, .{ .method = .POST, .path = path, .query = params, .body = body }, request_options);
}
pub fn getMapping(client: anytype, id: []const u8, request_options: options_mod.RequestOptions) !MappingResponse {
    return getMappingWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, id, request_options);
}
pub fn getMappingWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, id: []const u8, request_options: options_mod.RequestOptions) !MappingResponse {
    const path = try resourcePath(allocator, "/scim/group-mappings", id);
    defer allocator.free(path);
    const params: ?[]const u8 = null;
    const body: ?[]const u8 = null;
    return execute(MappingResponse, allocator, config, transport, .{ .method = .GET, .path = path, .query = params, .body = body }, request_options);
}
pub fn updateMapping(client: anytype, id: []const u8, request: UpdateMappingRequest, request_options: options_mod.RequestOptions) !MappingResponse {
    return updateMappingWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, id, request, request_options);
}
pub fn updateMappingWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, id: []const u8, request: UpdateMappingRequest, request_options: options_mod.RequestOptions) !MappingResponse {
    const path = try resourcePath(allocator, "/scim/group-mappings", id);
    defer allocator.free(path);
    const params: ?[]const u8 = null;
    const body = try json.stringifyRequest(allocator, request);
    defer allocator.free(body);
    return execute(MappingResponse, allocator, config, transport, .{ .method = .PATCH, .path = path, .query = params, .body = body }, request_options);
}
pub fn deleteMapping(client: anytype, id: []const u8, request: DeleteMappingRequest, request_options: options_mod.RequestOptions) !DeleteMappingResponse {
    return deleteMappingWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, id, request, request_options);
}
pub fn deleteMappingWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, id: []const u8, request: DeleteMappingRequest, request_options: options_mod.RequestOptions) !DeleteMappingResponse {
    const path = try resourcePath(allocator, "/scim/group-mappings", id);
    defer allocator.free(path);
    const params = if (request.keep_members) "keep_members=true" else "keep_members=false";
    const body: ?[]const u8 = null;
    return execute(DeleteMappingResponse, allocator, config, transport, .{ .method = .DELETE, .path = path, .query = params, .body = body }, request_options);
}
pub fn createSyncJob(client: anytype, request_options: options_mod.RequestOptions) !SyncJobResponse {
    return createSyncJobWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, request_options);
}
pub fn createSyncJobWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, request_options: options_mod.RequestOptions) !SyncJobResponse {
    const path = "/scim/sync-jobs";
    const params: ?[]const u8 = null;
    const body: ?[]const u8 = null;
    return execute(SyncJobResponse, allocator, config, transport, .{ .method = .POST, .path = path, .query = params, .body = body }, request_options);
}
pub fn getSyncJob(client: anytype, id: []const u8, request_options: options_mod.RequestOptions) !SyncJobResponse {
    return getSyncJobWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, id, request_options);
}
pub fn getSyncJobWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, id: []const u8, request_options: options_mod.RequestOptions) !SyncJobResponse {
    const path = try resourcePath(allocator, "/scim/sync-jobs", id);
    defer allocator.free(path);
    const params: ?[]const u8 = null;
    const body: ?[]const u8 = null;
    return execute(SyncJobResponse, allocator, config, transport, .{ .method = .GET, .path = path, .query = params, .body = body }, request_options);
}

fn resourcePath(allocator: std.mem.Allocator, prefix: []const u8, id: []const u8) ![]u8 {
    if (id.len == 0 or std.mem.eql(u8, id, ".") or std.mem.eql(u8, id, "..")) return error.InvalidPath;
    var path: std.ArrayList(u8) = .empty;
    errdefer path.deinit(allocator);
    try path.appendSlice(allocator, prefix);
    try path.append(allocator, '/');
    const hex = "0123456789ABCDEF";
    for (id) |byte| {
        if (std.ascii.isAlphanumeric(byte) or byte == '-' or byte == '_' or byte == '.' or byte == '~') {
            try path.append(allocator, byte);
        } else {
            try path.appendSlice(allocator, &.{ '%', hex[byte >> 4], hex[byte & 0x0F] });
        }
    }
    return path.toOwnedSlice(allocator);
}

fn execute(comptime T: type, allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, spec: http.HttpRequest, request_options: options_mod.RequestOptions) !T {
    var prepared = try http.prepareRequest(allocator, config, spec, request_options);
    defer prepared.deinit();
    var response = try transport.execute(allocator, prepared);
    defer response.deinit();
    if (@backingInt(response.status) < 200 or @backingInt(response.status) >= 300) return error.ApiError;
    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const Wire = switch (T) {
        ListMappingsResponse => struct { data: []GroupMapping, total_count: u64 },
        ListGroupsResponse => struct { data: []Group, total_count: u64 },
        MappingResponse => struct { data: GroupMapping },
        SyncJobResponse => struct { data: SyncJob },
        DeleteMappingResponse => struct { deleted: bool },
        else => unreachable,
    };
    const parsed = try json.parseResponseLeaky(Wire, arena.allocator(), try arena.allocator().dupe(u8, response.body));
    if (T == DeleteMappingResponse) {
        if (!parsed.deleted) return error.InvalidResponse;
    }
    var result: T = undefined;
    if (T == DeleteMappingResponse) {
        result.deleted = parsed.deleted;
    } else {
        result.data = parsed.data;
        if (T == ListMappingsResponse or T == ListGroupsResponse) result.total_count = parsed.total_count;
    }
    result.arena = arena;
    result.response_metadata = try http.ResponseMetadata.fromHttpResponse(arena.allocator(), response);
    return result;
}

const Capture = struct {
    method: std.http.Method,
    path: []const u8,
    body: ?[]const u8 = null,
    response: []const u8,
    status: std.http.Status = .ok,
    pub fn execute(self: @This(), allocator: std.mem.Allocator, prepared: http.PreparedRequest) !http.HttpResponse {
        try std.testing.expectEqual(self.method, prepared.method);
        const expected_url = try std.fmt.allocPrint(allocator, "https://openrouter.ai/api/v1{s}", .{self.path});
        defer allocator.free(expected_url);
        try std.testing.expectEqualStrings(expected_url, prepared.url);
        if (self.body) |body| {
            try std.testing.expectEqualStrings(body, prepared.body.?);
        } else try std.testing.expect(prepared.body == null);
        try std.testing.expectEqualStrings("test", prepared.headers[prepared.headers.len - 1].value);
        return (http.FakeTransport{ .status = self.status, .body = self.response, .headers = &.{.{ .name = "x-request-id", .value = "req_scim" }} }).execute(allocator, prepared);
    }
};
const test_options: options_mod.RequestOptions = .{ .extra_headers = &.{.{ .name = "X-Test", .value = "test" }} };
const test_config: config_mod.Config = .{ .api_key = "test-key" };
const mapping_body = "{\"data\": {\"id\": \"m1\", \"organization_id\": \"org\", \"scim_group_id\": \"g1\", \"workspace_id\": \"w1\", \"role\": \"future\", \"created_at\": \"created\", \"updated_at\": \"updated\", \"extra\": true}}";
const job_body = "{\"data\": {\"id\": \"j1\", \"status\": \"queued\", \"synced_groups\": null, \"deleted_groups\": null, \"error_message\": null, \"created_at\": \"created\", \"started_at\": null, \"finished_at\": null}}";
test "SCIM listMappings constructs request and owns parsed response" {
    var result = try listMappingsWithTransport(std.testing.allocator, test_config, Capture{ .method = .GET, .path = "/scim/group-mappings?offset=0&limit=100", .body = null, .response = "{\"data\": [{\"id\": \"m1\", \"organization_id\": \"org\", \"scim_group_id\": \"g1\", \"workspace_id\": \"w1\", \"role\": \"future\", \"created_at\": \"created\", \"updated_at\": \"updated\", \"extra\": true}], \"total_count\": 1}", .status = .ok }, .{ .offset = 0, .limit = 100 }, test_options);
    defer result.deinit();
    try std.testing.expectEqualStrings("req_scim", result.response_metadata.request_id.?);
    try std.testing.expectEqualStrings("future", result.data[0].role);
}
test "SCIM listGroups constructs request and owns parsed response" {
    var result = try listGroupsWithTransport(std.testing.allocator, test_config, Capture{ .method = .GET, .path = "/scim/groups?display_name=R%26D&external_id=a%2Fb", .body = null, .response = "{\"data\": [{\"id\": \"g\", \"organization_id\": \"o\", \"external_id\": null, \"display_name\": \"R&D\", \"created_at\": \"c\", \"updated_at\": \"u\"}], \"total_count\": 1}", .status = .ok }, .{ .display_name = "R&D", .external_id = "a/b" }, test_options);
    defer result.deinit();
    try std.testing.expectEqualStrings("req_scim", result.response_metadata.request_id.?);
    try std.testing.expect(result.data[0].external_id == null);
}
test "SCIM createMapping constructs request and owns parsed response" {
    var result = try createMappingWithTransport(std.testing.allocator, test_config, Capture{ .method = .POST, .path = "/scim/group-mappings", .body = "{\"scim_group_id\":\"g1\",\"workspace_id\":\"w1\",\"role\":\"member\"}", .response = mapping_body, .status = .created }, .{ .scim_group_id = "g1", .workspace_id = "w1", .role = .member }, test_options);
    defer result.deinit();
    try std.testing.expectEqualStrings("req_scim", result.response_metadata.request_id.?);
}
test "SCIM getMapping constructs request and owns parsed response" {
    var result = try getMappingWithTransport(std.testing.allocator, test_config, Capture{ .method = .GET, .path = "/scim/group-mappings/a%2Fb%3F", .body = null, .response = mapping_body, .status = .ok }, "a/b?", test_options);
    defer result.deinit();
    try std.testing.expectEqualStrings("req_scim", result.response_metadata.request_id.?);
}
test "SCIM updateMapping constructs request and owns parsed response" {
    var result = try updateMappingWithTransport(std.testing.allocator, test_config, Capture{ .method = .PATCH, .path = "/scim/group-mappings/m1", .body = "{\"role\":\"admin\"}", .response = mapping_body, .status = .ok }, "m1", .{ .role = .admin }, test_options);
    defer result.deinit();
    try std.testing.expectEqualStrings("req_scim", result.response_metadata.request_id.?);
}
test "SCIM deleteMapping constructs request and owns parsed response" {
    var result = try deleteMappingWithTransport(std.testing.allocator, test_config, Capture{ .method = .DELETE, .path = "/scim/group-mappings/m1?keep_members=false", .body = null, .response = "{\"deleted\":true}", .status = .ok }, "m1", .{ .keep_members = false }, test_options);
    defer result.deinit();
    try std.testing.expectEqualStrings("req_scim", result.response_metadata.request_id.?);
    try std.testing.expect(result.deleted);
}
test "SCIM createSyncJob constructs request and owns parsed response" {
    var result = try createSyncJobWithTransport(std.testing.allocator, test_config, Capture{ .method = .POST, .path = "/scim/sync-jobs", .body = null, .response = job_body, .status = .accepted }, test_options);
    defer result.deinit();
    try std.testing.expectEqualStrings("req_scim", result.response_metadata.request_id.?);
    try std.testing.expectEqualStrings("queued", result.data.status);
}
test "SCIM getSyncJob constructs request and owns parsed response" {
    var result = try getSyncJobWithTransport(std.testing.allocator, test_config, Capture{ .method = .GET, .path = "/scim/sync-jobs/j1", .body = null, .response = job_body, .status = .ok }, "j1", test_options);
    defer result.deinit();
    try std.testing.expectEqualStrings("req_scim", result.response_metadata.request_id.?);
    try std.testing.expect(result.data.finished_at == null);
}
test "SCIM rejects malformed responses, invalid identifiers, and access errors" {
    const allocator = std.testing.allocator;
    try std.testing.expectError(error.MissingField, getMappingWithTransport(allocator, test_config, http.FakeTransport{ .body = "{}" }, "m", .{}));
    try std.testing.expectError(error.InvalidResponse, deleteMappingWithTransport(allocator, test_config, http.FakeTransport{ .body = "{\"deleted\":false}" }, "m", .{ .keep_members = true }, .{}));
    for ([_][]const u8{ "", ".", ".." }) |id| {
        try std.testing.expectError(error.InvalidPath, getMappingWithTransport(allocator, test_config, http.FakeTransport{}, id, .{}));
        try std.testing.expectError(error.InvalidPath, getSyncJobWithTransport(allocator, test_config, http.FakeTransport{}, id, .{}));
    }
    try std.testing.expectError(error.ApiError, listMappingsWithTransport(allocator, test_config, http.FakeTransport{ .status = .forbidden }, .{ .offset = 0, .limit = 100 }, .{}));
    try std.testing.expectError(error.ApiError, listGroupsWithTransport(allocator, test_config, http.FakeTransport{ .status = .forbidden }, .{ .display_name = "R&D", .external_id = "a/b" }, .{}));
    try std.testing.expectError(error.ApiError, createMappingWithTransport(allocator, test_config, http.FakeTransport{ .status = .forbidden }, .{ .scim_group_id = "g1", .workspace_id = "w1", .role = .member }, .{}));
    try std.testing.expectError(error.ApiError, getMappingWithTransport(allocator, test_config, http.FakeTransport{ .status = .forbidden }, "a/b?", .{}));
    try std.testing.expectError(error.ApiError, updateMappingWithTransport(allocator, test_config, http.FakeTransport{ .status = .forbidden }, "m1", .{ .role = .admin }, .{}));
    try std.testing.expectError(error.ApiError, deleteMappingWithTransport(allocator, test_config, http.FakeTransport{ .status = .forbidden }, "m1", .{ .keep_members = false }, .{}));
    try std.testing.expectError(error.ApiError, createSyncJobWithTransport(allocator, test_config, http.FakeTransport{ .status = .forbidden }, .{}));
    try std.testing.expectError(error.ApiError, getSyncJobWithTransport(allocator, test_config, http.FakeTransport{ .status = .forbidden }, "j1", .{}));
}

test "SCIM default pagination and empty lists" {
    var mappings = try listMappingsWithTransport(std.testing.allocator, test_config, Capture{ .method = .GET, .path = "/scim/group-mappings", .response = "{\"data\":[],\"total_count\":0}" }, .{}, test_options);
    defer mappings.deinit();
    try std.testing.expectEqual(@as(usize, 0), mappings.data.len);
    try std.testing.expectEqual(@as(u64, 0), mappings.total_count);
    var groups = try listGroupsWithTransport(std.testing.allocator, test_config, Capture{ .method = .GET, .path = "/scim/groups", .response = "{\"data\":[],\"total_count\":0}" }, .{}, test_options);
    defer groups.deinit();
    try std.testing.expectEqual(@as(usize, 0), groups.data.len);
}

test "SCIM deletion explicitly retains memberships" {
    var result = try deleteMappingWithTransport(std.testing.allocator, test_config, Capture{ .method = .DELETE, .path = "/scim/group-mappings/m?keep_members=true", .response = "{\"deleted\":true}" }, "m", .{ .keep_members = true }, test_options);
    defer result.deinit();
    try std.testing.expect(result.deleted);
}

test "SCIM sync preserves terminal and unknown states and failure details" {
    for ([_][]const u8{ "succeeded", "failed", "future" }) |status| {
        const body = try std.fmt.allocPrint(std.testing.allocator, "{{\"data\":{{\"id\":\"j\",\"status\":\"{s}\",\"synced_groups\":0,\"deleted_groups\":2,\"error_message\":\"directory unavailable\",\"created_at\":\"c\",\"started_at\":\"s\",\"finished_at\":\"f\"}}}}", .{status});
        defer std.testing.allocator.free(body);
        var result = try getSyncJobWithTransport(std.testing.allocator, test_config, http.FakeTransport{ .body = body }, "j", .{});
        defer result.deinit();
        try std.testing.expectEqualStrings(status, result.data.status);
        try std.testing.expectEqual(@as(u64, 0), result.data.synced_groups.?);
        try std.testing.expectEqual(@as(u64, 2), result.data.deleted_groups.?);
        try std.testing.expectEqualStrings("directory unavailable", result.data.error_message.?);
        try std.testing.expectEqualStrings("f", result.data.finished_at.?);
    }
}
