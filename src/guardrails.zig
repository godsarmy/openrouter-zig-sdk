//! Guardrails management API.

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
};

pub const AssignmentListRequest = struct {
    offset: ?i64 = null,
    limit: ?i64 = null,
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
    name: []const u8,
    description: ?[]const u8 = null,
    workspace_id: ?[]const u8 = null,
    limit_usd: ?f64 = null,
    reset_interval: ?[]const u8 = null,
    allowed_models: ?StringList = null,
    allowed_providers: ?StringList = null,
    ignored_models: ?StringList = null,
    ignored_providers: ?StringList = null,
    enforce_zdr: ?bool = null,
    enforce_zdr_anthropic: ?bool = null,
    enforce_zdr_openai: ?bool = null,
    enforce_zdr_google: ?bool = null,
    enforce_zdr_other: ?bool = null,
    content_filters: ?[]const std.json.Value = null,
    content_filter_builtins: ?[]const std.json.Value = null,
};

pub const UpdateRequest = struct {
    name: ?[]const u8 = null,
    description: ?[]const u8 = null,
    limit_usd: ?f64 = null,
    reset_interval: ?[]const u8 = null,
    allowed_models: ?StringList = null,
    allowed_providers: ?StringList = null,
    ignored_models: ?StringList = null,
    ignored_providers: ?StringList = null,
    enforce_zdr: ?bool = null,
    enforce_zdr_anthropic: ?bool = null,
    enforce_zdr_openai: ?bool = null,
    enforce_zdr_google: ?bool = null,
    enforce_zdr_other: ?bool = null,
    content_filters: ?[]const std.json.Value = null,
    content_filter_builtins: ?[]const std.json.Value = null,
};

pub const BulkKeyAssignmentRequest = struct { key_hashes: []const []const u8 };
pub const BulkMemberAssignmentRequest = struct { member_user_ids: []const []const u8 };

pub const Guardrail = struct {
    id: ?[]const u8 = null,
    name: ?[]const u8 = null,
    description: ?[]const u8 = null,
    workspace_id: ?[]const u8 = null,
    limit_usd: ?f64 = null,
    reset_interval: ?[]const u8 = null,
    allowed_models: ?[]const []const u8 = null,
    allowed_providers: ?[]const []const u8 = null,
    ignored_models: ?[]const []const u8 = null,
    ignored_providers: ?[]const []const u8 = null,
    enforce_zdr: ?bool = null,
    enforce_zdr_anthropic: ?bool = null,
    enforce_zdr_openai: ?bool = null,
    enforce_zdr_google: ?bool = null,
    enforce_zdr_other: ?bool = null,
    content_filters: ?[]std.json.Value = null,
    content_filter_builtins: ?[]std.json.Value = null,
    created_at: ?[]const u8 = null,
    updated_at: ?[]const u8 = null,
};

pub const KeyAssignment = struct {
    id: ?[]const u8 = null,
    guardrail_id: ?[]const u8 = null,
    key_hash: ?[]const u8 = null,
    key_label: ?[]const u8 = null,
    key_name: ?[]const u8 = null,
    assigned_by: ?[]const u8 = null,
    created_at: ?[]const u8 = null,
};

pub const MemberAssignment = struct {
    id: ?[]const u8 = null,
    guardrail_id: ?[]const u8 = null,
    organization_id: ?[]const u8 = null,
    user_id: ?[]const u8 = null,
    assigned_by: ?[]const u8 = null,
    created_at: ?[]const u8 = null,
};

pub const ListResponse = responseWithList(Guardrail);
pub const CreateResponse = responseWithData(Guardrail);
pub const GetResponse = responseWithData(Guardrail);
pub const UpdateResponse = responseWithData(Guardrail);
pub const KeyAssignmentsListResponse = responseWithList(KeyAssignment);
pub const MemberAssignmentsListResponse = responseWithList(MemberAssignment);

pub const DeleteResponse = struct {
    arena: std.heap.ArenaAllocator,
    deleted: bool,

    pub fn deinit(self: *DeleteResponse) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

pub const BulkAssignResponse = struct {
    arena: std.heap.ArenaAllocator,
    assigned_count: ?i64 = null,

    pub fn deinit(self: *BulkAssignResponse) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

pub const BulkUnassignResponse = struct {
    arena: std.heap.ArenaAllocator,
    unassigned_count: ?i64 = null,

    pub fn deinit(self: *BulkUnassignResponse) void {
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

const WireListResponse = struct { data: []Guardrail, total_count: ?i64 = null };
const WireDataResponse = struct { data: Guardrail };
const WireDeleteResponse = struct { deleted: bool };
const WireKeyAssignmentsListResponse = struct { data: []KeyAssignment, total_count: ?i64 = null };
const WireMemberAssignmentsListResponse = struct { data: []MemberAssignment, total_count: ?i64 = null };
const WireBulkAssignResponse = struct { assigned_count: ?i64 = null };
const WireBulkUnassignResponse = struct { unassigned_count: ?i64 = null };

pub fn list(client: anytype, request: ListRequest, request_options: options_mod.RequestOptions) !ListResponse {
    return listWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, request, request_options);
}

pub fn listWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, request: ListRequest, request_options: options_mod.RequestOptions) !ListResponse {
    const query = try listQueryString(allocator, request);
    defer allocator.free(query);
    var response = try execute(allocator, config, transport, .{ .method = .GET, .path = "/guardrails", .query = query }, request_options);
    defer response.deinit();
    return parseListResponse(allocator, response);
}

pub fn create(client: anytype, request: CreateRequest, request_options: options_mod.RequestOptions) !CreateResponse {
    return createWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, request, request_options);
}

pub fn createWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, request: CreateRequest, request_options: options_mod.RequestOptions) !CreateResponse {
    const body = try json.stringifyRequest(allocator, request);
    defer allocator.free(body);
    var response = try execute(allocator, config, transport, .{ .method = .POST, .path = "/guardrails", .body = body }, request_options);
    defer response.deinit();
    return parseCreateResponse(allocator, response);
}

pub fn get(client: anytype, id: []const u8, request_options: options_mod.RequestOptions) !GetResponse {
    return getWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, id, request_options);
}

pub fn getWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, id: []const u8, request_options: options_mod.RequestOptions) !GetResponse {
    const path = try guardrailPath(allocator, id, "");
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
    const path = try guardrailPath(allocator, id, "");
    defer allocator.free(path);
    var response = try execute(allocator, config, transport, .{ .method = .PATCH, .path = path, .body = body }, request_options);
    defer response.deinit();
    return parseUpdateResponse(allocator, response);
}

pub fn delete(client: anytype, id: []const u8, request_options: options_mod.RequestOptions) !DeleteResponse {
    return deleteWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, id, request_options);
}

pub fn deleteWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, id: []const u8, request_options: options_mod.RequestOptions) !DeleteResponse {
    const path = try guardrailPath(allocator, id, "");
    defer allocator.free(path);
    var response = try execute(allocator, config, transport, .{ .method = .DELETE, .path = path }, request_options);
    defer response.deinit();
    return parseDeleteResponse(allocator, response);
}

pub fn listKeyAssignments(client: anytype, request: AssignmentListRequest, request_options: options_mod.RequestOptions) !KeyAssignmentsListResponse {
    return listKeyAssignmentsWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, request, request_options);
}

pub fn listKeyAssignmentsWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, request: AssignmentListRequest, request_options: options_mod.RequestOptions) !KeyAssignmentsListResponse {
    const query = try assignmentListQueryString(allocator, request);
    defer allocator.free(query);
    var response = try execute(allocator, config, transport, .{ .method = .GET, .path = "/guardrails/assignments/keys", .query = query }, request_options);
    defer response.deinit();
    return parseKeyAssignmentsListResponse(allocator, response);
}

pub fn listGuardrailKeyAssignments(client: anytype, id: []const u8, request: AssignmentListRequest, request_options: options_mod.RequestOptions) !KeyAssignmentsListResponse {
    return listGuardrailKeyAssignmentsWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, id, request, request_options);
}

pub fn listGuardrailKeyAssignmentsWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, id: []const u8, request: AssignmentListRequest, request_options: options_mod.RequestOptions) !KeyAssignmentsListResponse {
    const query = try assignmentListQueryString(allocator, request);
    defer allocator.free(query);
    const path = try guardrailPath(allocator, id, "/assignments/keys");
    defer allocator.free(path);
    var response = try execute(allocator, config, transport, .{ .method = .GET, .path = path, .query = query }, request_options);
    defer response.deinit();
    return parseKeyAssignmentsListResponse(allocator, response);
}

pub fn bulkAssignKeys(client: anytype, id: []const u8, request: BulkKeyAssignmentRequest, request_options: options_mod.RequestOptions) !BulkAssignResponse {
    return bulkAssignKeysWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, id, request, request_options);
}

pub fn bulkAssignKeysWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, id: []const u8, request: BulkKeyAssignmentRequest, request_options: options_mod.RequestOptions) !BulkAssignResponse {
    return bulkAssign(allocator, config, transport, id, "/assignments/keys", request, request_options);
}

pub fn bulkUnassignKeys(client: anytype, id: []const u8, request: BulkKeyAssignmentRequest, request_options: options_mod.RequestOptions) !BulkUnassignResponse {
    return bulkUnassignKeysWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, id, request, request_options);
}

pub fn bulkUnassignKeysWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, id: []const u8, request: BulkKeyAssignmentRequest, request_options: options_mod.RequestOptions) !BulkUnassignResponse {
    return bulkUnassign(allocator, config, transport, id, "/assignments/keys/remove", request, request_options);
}

pub fn listMemberAssignments(client: anytype, request: AssignmentListRequest, request_options: options_mod.RequestOptions) !MemberAssignmentsListResponse {
    return listMemberAssignmentsWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, request, request_options);
}

pub fn listMemberAssignmentsWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, request: AssignmentListRequest, request_options: options_mod.RequestOptions) !MemberAssignmentsListResponse {
    const query = try assignmentListQueryString(allocator, request);
    defer allocator.free(query);
    var response = try execute(allocator, config, transport, .{ .method = .GET, .path = "/guardrails/assignments/members", .query = query }, request_options);
    defer response.deinit();
    return parseMemberAssignmentsListResponse(allocator, response);
}

pub fn listGuardrailMemberAssignments(client: anytype, id: []const u8, request: AssignmentListRequest, request_options: options_mod.RequestOptions) !MemberAssignmentsListResponse {
    return listGuardrailMemberAssignmentsWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, id, request, request_options);
}

pub fn listGuardrailMemberAssignmentsWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, id: []const u8, request: AssignmentListRequest, request_options: options_mod.RequestOptions) !MemberAssignmentsListResponse {
    const query = try assignmentListQueryString(allocator, request);
    defer allocator.free(query);
    const path = try guardrailPath(allocator, id, "/assignments/members");
    defer allocator.free(path);
    var response = try execute(allocator, config, transport, .{ .method = .GET, .path = path, .query = query }, request_options);
    defer response.deinit();
    return parseMemberAssignmentsListResponse(allocator, response);
}

pub fn bulkAssignMembers(client: anytype, id: []const u8, request: BulkMemberAssignmentRequest, request_options: options_mod.RequestOptions) !BulkAssignResponse {
    return bulkAssignMembersWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, id, request, request_options);
}

pub fn bulkAssignMembersWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, id: []const u8, request: BulkMemberAssignmentRequest, request_options: options_mod.RequestOptions) !BulkAssignResponse {
    return bulkAssign(allocator, config, transport, id, "/assignments/members", request, request_options);
}

pub fn bulkUnassignMembers(client: anytype, id: []const u8, request: BulkMemberAssignmentRequest, request_options: options_mod.RequestOptions) !BulkUnassignResponse {
    return bulkUnassignMembersWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, id, request, request_options);
}

pub fn bulkUnassignMembersWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, id: []const u8, request: BulkMemberAssignmentRequest, request_options: options_mod.RequestOptions) !BulkUnassignResponse {
    return bulkUnassign(allocator, config, transport, id, "/assignments/members/remove", request, request_options);
}

fn bulkAssign(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, id: []const u8, suffix: []const u8, request: anytype, request_options: options_mod.RequestOptions) !BulkAssignResponse {
    const body = try json.stringifyRequest(allocator, request);
    defer allocator.free(body);
    const path = try guardrailPath(allocator, id, suffix);
    defer allocator.free(path);
    var response = try execute(allocator, config, transport, .{ .method = .POST, .path = path, .body = body }, request_options);
    defer response.deinit();
    return parseBulkAssignResponse(allocator, response);
}

fn bulkUnassign(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, id: []const u8, suffix: []const u8, request: anytype, request_options: options_mod.RequestOptions) !BulkUnassignResponse {
    const body = try json.stringifyRequest(allocator, request);
    defer allocator.free(body);
    const path = try guardrailPath(allocator, id, suffix);
    defer allocator.free(path);
    var response = try execute(allocator, config, transport, .{ .method = .POST, .path = path, .body = body }, request_options);
    defer response.deinit();
    return parseBulkUnassignResponse(allocator, response);
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

pub fn parseKeyAssignmentsListResponse(allocator: std.mem.Allocator, response: http.HttpResponse) !KeyAssignmentsListResponse {
    if (errors.isErrorStatus(@intFromEnum(response.status))) return error.ApiError;
    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const parsed = try json.parseResponseLeaky(WireKeyAssignmentsListResponse, arena.allocator(), try arena.allocator().dupe(u8, response.body));
    return .{ .arena = arena, .data = parsed.data, .total_count = parsed.total_count };
}

pub fn parseMemberAssignmentsListResponse(allocator: std.mem.Allocator, response: http.HttpResponse) !MemberAssignmentsListResponse {
    if (errors.isErrorStatus(@intFromEnum(response.status))) return error.ApiError;
    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const parsed = try json.parseResponseLeaky(WireMemberAssignmentsListResponse, arena.allocator(), try arena.allocator().dupe(u8, response.body));
    return .{ .arena = arena, .data = parsed.data, .total_count = parsed.total_count };
}

pub fn parseBulkAssignResponse(allocator: std.mem.Allocator, response: http.HttpResponse) !BulkAssignResponse {
    if (errors.isErrorStatus(@intFromEnum(response.status))) return error.ApiError;
    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const parsed = try json.parseResponseLeaky(WireBulkAssignResponse, arena.allocator(), try arena.allocator().dupe(u8, response.body));
    return .{ .arena = arena, .assigned_count = parsed.assigned_count };
}

pub fn parseBulkUnassignResponse(allocator: std.mem.Allocator, response: http.HttpResponse) !BulkUnassignResponse {
    if (errors.isErrorStatus(@intFromEnum(response.status))) return error.ApiError;
    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const parsed = try json.parseResponseLeaky(WireBulkUnassignResponse, arena.allocator(), try arena.allocator().dupe(u8, response.body));
    return .{ .arena = arena, .unassigned_count = parsed.unassigned_count };
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
    });
}

fn assignmentListQueryString(allocator: std.mem.Allocator, request: AssignmentListRequest) ![]u8 {
    const offset_str = if (request.offset) |value| try std.fmt.allocPrint(allocator, "{d}", .{value}) else null;
    defer if (offset_str) |value| allocator.free(value);
    const limit_str = if (request.limit) |value| try std.fmt.allocPrint(allocator, "{d}", .{value}) else null;
    defer if (limit_str) |value| allocator.free(value);
    return query_mod.build(allocator, &.{
        .{ .name = "offset", .value = offset_str },
        .{ .name = "limit", .value = limit_str },
    });
}

fn guardrailPath(allocator: std.mem.Allocator, id: []const u8, suffix: []const u8) ![]u8 {
    return std.fmt.allocPrint(allocator, "/guardrails/{s}{s}", .{ id, suffix });
}

test "guardrails list serializes query params" {
    const query = try listQueryString(std.testing.allocator, .{ .offset = 1, .limit = 20, .workspace_id = "ws_123" });
    defer std.testing.allocator.free(query);
    try std.testing.expectEqualStrings("offset=1&limit=20&workspace_id=ws_123", query);
}

test "guardrails create serializes request" {
    const body = try json.stringifyRequest(std.testing.allocator, CreateRequest{
        .name = "Budget guardrail",
        .limit_usd = 100,
        .reset_interval = "monthly",
        .allowed_models = .{ .values = &.{"openai/gpt-4o"} },
        .enforce_zdr_openai = true,
    });
    defer std.testing.allocator.free(body);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"name\":\"Budget guardrail\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"limit_usd\":1e2") != null or std.mem.indexOf(u8, body, "\"limit_usd\":100") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"allowed_models\":[\"openai/gpt-4o\"]") != null);
}

test "guardrails update can serialize nullable lists" {
    const body = try json.stringifyRequest(std.testing.allocator, UpdateRequest{ .allowed_models = .null_value, .ignored_providers = .{ .values = &.{"provider-a"} } });
    defer std.testing.allocator.free(body);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"allowed_models\":null") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"ignored_providers\":[\"provider-a\"]") != null);
}

test "guardrails list parses response" {
    var result = try listWithTransport(std.testing.allocator, .{ .api_key = "test-key" }, http.FakeTransport{ .body = "{\"data\":[{\"id\":\"gr_123\",\"name\":\"Budget\",\"limit_usd\":100,\"allowed_models\":[\"openai/gpt-4o\"]}],\"total_count\":1}" }, .{}, .{});
    defer result.deinit();
    try std.testing.expectEqual(@as(usize, 1), result.data.len);
    try std.testing.expectEqual(@as(?i64, 1), result.total_count);
    try std.testing.expectEqualStrings("gr_123", result.data[0].id.?);
    try std.testing.expectEqualStrings("openai/gpt-4o", result.data[0].allowed_models.?[0]);
}

test "guardrails create sends POST /guardrails" {
    const body = try json.stringifyRequest(std.testing.allocator, CreateRequest{ .name = "Budget" });
    defer std.testing.allocator.free(body);
    var prepared = try http.prepareRequest(std.testing.allocator, .{ .api_key = "test-key" }, .{ .method = .POST, .path = "/guardrails", .body = body }, .{});
    defer prepared.deinit();
    try std.testing.expectEqual(std.http.Method.POST, prepared.method);
    try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/guardrails", prepared.url);
}

test "guardrails item endpoints build paths" {
    const path = try guardrailPath(std.testing.allocator, "gr_123", "/assignments/keys/remove");
    defer std.testing.allocator.free(path);
    try std.testing.expectEqualStrings("/guardrails/gr_123/assignments/keys/remove", path);
}

test "guardrails key assignment request serializes" {
    const body = try json.stringifyRequest(std.testing.allocator, BulkKeyAssignmentRequest{ .key_hashes = &.{ "hash1", "hash2" } });
    defer std.testing.allocator.free(body);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"key_hashes\":[\"hash1\",\"hash2\"]") != null);
}

test "guardrails member assignment request serializes" {
    const body = try json.stringifyRequest(std.testing.allocator, BulkMemberAssignmentRequest{ .member_user_ids = &.{"user1"} });
    defer std.testing.allocator.free(body);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"member_user_ids\":[\"user1\"]") != null);
}

test "guardrails parses assignment and bulk responses" {
    var keys = try listKeyAssignmentsWithTransport(std.testing.allocator, .{ .api_key = "test-key" }, http.FakeTransport{ .body = "{\"data\":[{\"id\":\"asg_1\",\"guardrail_id\":\"gr_123\",\"key_hash\":\"hash1\",\"key_label\":\"Key\"}],\"total_count\":1}" }, .{}, .{});
    defer keys.deinit();
    try std.testing.expectEqualStrings("hash1", keys.data[0].key_hash.?);

    var members = try listMemberAssignmentsWithTransport(std.testing.allocator, .{ .api_key = "test-key" }, http.FakeTransport{ .body = "{\"data\":[{\"id\":\"asg_2\",\"guardrail_id\":\"gr_123\",\"organization_id\":\"org_1\",\"user_id\":\"user1\"}],\"total_count\":1}" }, .{}, .{});
    defer members.deinit();
    try std.testing.expectEqualStrings("org_1", members.data[0].organization_id.?);
    try std.testing.expectEqualStrings("user1", members.data[0].user_id.?);

    var assigned = try bulkAssignKeysWithTransport(std.testing.allocator, .{ .api_key = "test-key" }, http.FakeTransport{ .body = "{\"assigned_count\":2}" }, "gr_123", .{ .key_hashes = &.{ "h1", "h2" } }, .{});
    defer assigned.deinit();
    try std.testing.expectEqual(@as(?i64, 2), assigned.assigned_count);

    var unassigned = try bulkUnassignMembersWithTransport(std.testing.allocator, .{ .api_key = "test-key" }, http.FakeTransport{ .body = "{\"unassigned_count\":1}" }, "gr_123", .{ .member_user_ids = &.{"user1"} }, .{});
    defer unassigned.deinit();
    try std.testing.expectEqual(@as(?i64, 1), unassigned.unassigned_count);
}

test "guardrails create get update delete parse responses" {
    var created = try createWithTransport(std.testing.allocator, .{ .api_key = "test-key" }, http.FakeTransport{ .status = .created, .body = "{\"data\":{\"id\":\"gr_123\",\"name\":\"Budget\"}}" }, .{ .name = "Budget" }, .{});
    defer created.deinit();
    try std.testing.expectEqualStrings("gr_123", created.data.id.?);

    var got = try getWithTransport(std.testing.allocator, .{ .api_key = "test-key" }, http.FakeTransport{ .body = "{\"data\":{\"id\":\"gr_123\",\"name\":\"Budget\"}}" }, "gr_123", .{});
    defer got.deinit();
    try std.testing.expectEqualStrings("Budget", got.data.name.?);

    var updated = try updateWithTransport(std.testing.allocator, .{ .api_key = "test-key" }, http.FakeTransport{ .body = "{\"data\":{\"id\":\"gr_123\",\"name\":\"Updated\"}}" }, "gr_123", .{ .name = "Updated" }, .{});
    defer updated.deinit();
    try std.testing.expectEqualStrings("Updated", updated.data.name.?);

    var deleted = try deleteWithTransport(std.testing.allocator, .{ .api_key = "test-key" }, http.FakeTransport{ .body = "{\"deleted\":true}" }, "gr_123", .{});
    defer deleted.deinit();
    try std.testing.expect(deleted.deleted);
}

test "guardrails error status maps to ApiError" {
    try std.testing.expectError(error.ApiError, listWithTransport(
        std.testing.allocator,
        .{ .api_key = "test-key" },
        http.FakeTransport{ .status = .forbidden, .body = "{\"error\":{\"message\":\"forbidden\"}}" },
        .{},
        .{},
    ));
}
