//! Management API keys API.

const std = @import("std");

const config_mod = @import("config.zig");
const errors = @import("errors.zig");
const http = @import("http.zig");
const json = @import("json.zig");
const options_mod = @import("options.zig");
const query_mod = @import("query.zig");

pub const ListRequest = struct {
    include_disabled: ?bool = null,
    offset: ?i64 = null,
    workspace_id: ?[]const u8 = null,
};

pub const CreateRequest = struct {
    name: []const u8,
    creator_user_id: ?[]const u8 = null,
    expires_at: ?[]const u8 = null,
    include_byok_in_limit: ?bool = null,
    limit: ?f64 = null,
    limit_reset: ?[]const u8 = null,
    workspace_id: ?[]const u8 = null,
};

pub const UpdateRequest = struct {
    disabled: ?bool = null,
    expires_at: ?[]const u8 = null,
    include_byok_in_limit: ?bool = null,
    limit: ?f64 = null,
    limit_reset: ?[]const u8 = null,
    name: ?[]const u8 = null,
};

pub const ListResponse = struct {
    arena: std.heap.ArenaAllocator,
    data: []ManagedApiKey,

    pub fn deinit(self: *ListResponse) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

pub const CreateResponse = struct {
    arena: std.heap.ArenaAllocator,
    data: ManagedApiKey,
    key: []const u8,

    pub fn deinit(self: *CreateResponse) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

pub const GetResponse = struct {
    arena: std.heap.ArenaAllocator,
    data: ManagedApiKey,

    pub fn deinit(self: *GetResponse) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

pub const UpdateResponse = struct {
    arena: std.heap.ArenaAllocator,
    data: ManagedApiKey,

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

pub const ManagedApiKey = struct {
    byok_usage: ?f64 = null,
    byok_usage_daily: ?f64 = null,
    byok_usage_monthly: ?f64 = null,
    byok_usage_weekly: ?f64 = null,
    created_at: ?[]const u8 = null,
    creator_user_id: ?[]const u8 = null,
    disabled: ?bool = null,
    expires_at: ?[]const u8 = null,
    hash: ?[]const u8 = null,
    include_byok_in_limit: ?bool = null,
    label: ?[]const u8 = null,
    limit: ?f64 = null,
    limit_remaining: ?f64 = null,
    limit_reset: ?[]const u8 = null,
    name: ?[]const u8 = null,
    updated_at: ?[]const u8 = null,
    usage: ?f64 = null,
    usage_daily: ?f64 = null,
    usage_monthly: ?f64 = null,
    usage_weekly: ?f64 = null,
    workspace_id: ?[]const u8 = null,
};

const WireListResponse = struct { data: []ManagedApiKey };
const WireCreateResponse = struct { data: ManagedApiKey, key: []const u8 };
const WireGetResponse = struct { data: ManagedApiKey };
const WireUpdateResponse = struct { data: ManagedApiKey };
const WireDeleteResponse = struct { deleted: bool };

pub fn list(client: anytype, request: ListRequest, request_options: options_mod.RequestOptions) !ListResponse {
    return listWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, request, request_options);
}

pub fn listWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, request: ListRequest, request_options: options_mod.RequestOptions) !ListResponse {
    const query = try listQueryString(allocator, request);
    defer allocator.free(query);
    var prepared = try http.prepareRequest(allocator, config, .{ .method = .GET, .path = "/keys", .query = query }, request_options);
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
    var prepared = try http.prepareRequest(allocator, config, .{ .method = .POST, .path = "/keys", .body = body }, request_options);
    defer prepared.deinit();
    var response = try transport.execute(allocator, prepared);
    defer response.deinit();
    return parseCreateResponse(allocator, response);
}

pub fn get(client: anytype, hash: []const u8, request_options: options_mod.RequestOptions) !GetResponse {
    return getWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, hash, request_options);
}
pub fn getWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, hash: []const u8, request_options: options_mod.RequestOptions) !GetResponse {
    const path = try std.fmt.allocPrint(allocator, "/keys/{s}", .{hash});
    defer allocator.free(path);
    var prepared = try http.prepareRequest(allocator, config, .{ .method = .GET, .path = path }, request_options);
    defer prepared.deinit();
    var response = try transport.execute(allocator, prepared);
    defer response.deinit();
    return parseGetResponse(allocator, response);
}

pub fn update(client: anytype, hash: []const u8, request: UpdateRequest, request_options: options_mod.RequestOptions) !UpdateResponse {
    return updateWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, hash, request, request_options);
}
pub fn updateWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, hash: []const u8, request: UpdateRequest, request_options: options_mod.RequestOptions) !UpdateResponse {
    const body = try json.stringifyRequest(allocator, request);
    defer allocator.free(body);
    const path = try std.fmt.allocPrint(allocator, "/keys/{s}", .{hash});
    defer allocator.free(path);
    var prepared = try http.prepareRequest(allocator, config, .{ .method = .PATCH, .path = path, .body = body }, request_options);
    defer prepared.deinit();
    var response = try transport.execute(allocator, prepared);
    defer response.deinit();
    return parseUpdateResponse(allocator, response);
}

pub fn delete(client: anytype, hash: []const u8, request_options: options_mod.RequestOptions) !DeleteResponse {
    return deleteWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, hash, request_options);
}
pub fn deleteWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, hash: []const u8, request_options: options_mod.RequestOptions) !DeleteResponse {
    const path = try std.fmt.allocPrint(allocator, "/keys/{s}", .{hash});
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
    return .{ .arena = arena, .data = parsed.data };
}

pub fn parseCreateResponse(allocator: std.mem.Allocator, response: http.HttpResponse) !CreateResponse {
    if (response.status != .created and errors.isErrorStatus(@intFromEnum(response.status))) return error.ApiError;
    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const parsed = try json.parseResponseLeaky(WireCreateResponse, arena.allocator(), try arena.allocator().dupe(u8, response.body));
    return .{ .arena = arena, .data = parsed.data, .key = parsed.key };
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
    return query_mod.build(allocator, &.{
        .{ .name = "include_disabled", .value = boolParam(request.include_disabled) },
        .{ .name = "offset", .value = offset_str },
        .{ .name = "workspace_id", .value = request.workspace_id },
    });
}

fn boolParam(value: ?bool) ?[]const u8 {
    return if (value) |v| if (v) "true" else "false" else null;
}

test "keys list serializes query params" {
    const query = try listQueryString(std.testing.allocator, .{ .include_disabled = true, .offset = 12, .workspace_id = "ws_123" });
    defer std.testing.allocator.free(query);
    try std.testing.expectEqualStrings("include_disabled=true&offset=12&workspace_id=ws_123", query);
}

test "keys list parses response" {
    const body =
        \\{"data":[{"hash":"h1","name":"Key","label":"Key","disabled":false}]}
    ;
    var result = try listWithTransport(std.testing.allocator, .{ .api_key = "test-key" }, http.FakeTransport{ .body = body }, .{}, .{});
    defer result.deinit();
    try std.testing.expectEqual(@as(usize, 1), result.data.len);
    try std.testing.expectEqualStrings("h1", result.data[0].hash.?);
}

test "keys create sends POST /keys" {
    const body = try json.stringifyRequest(std.testing.allocator, CreateRequest{ .name = "My Key" });
    defer std.testing.allocator.free(body);
    var prepared = try http.prepareRequest(std.testing.allocator, .{ .api_key = "test-key" }, .{ .method = .POST, .path = "/keys", .body = body }, .{});
    defer prepared.deinit();
    try std.testing.expectEqual(std.http.Method.POST, prepared.method);
    try std.testing.expectEqualStrings(body, prepared.body.?);
}
