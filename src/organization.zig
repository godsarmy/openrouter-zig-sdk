//! Organization management API.

const std = @import("std");

const config_mod = @import("config.zig");
const errors = @import("errors.zig");
const http = @import("http.zig");
const json = @import("json.zig");
const options_mod = @import("options.zig");
const query_mod = @import("query.zig");

pub const MembersListRequest = struct {
    offset: ?i64 = null,
    limit: ?i64 = null,
};

pub const OrganizationMember = struct {
    id: ?[]const u8 = null,
    email: ?[]const u8 = null,
    first_name: ?[]const u8 = null,
    last_name: ?[]const u8 = null,
    role: ?[]const u8 = null,
};

pub const MembersListResponse = struct {
    arena: std.heap.ArenaAllocator,
    data: []OrganizationMember,
    total_count: ?i64 = null,

    pub fn deinit(self: *MembersListResponse) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

const WireMembersListResponse = struct { data: []OrganizationMember, total_count: ?i64 = null };

pub fn listMembers(client: anytype, request: MembersListRequest, request_options: options_mod.RequestOptions) !MembersListResponse {
    return listMembersWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, request, request_options);
}

pub fn listMembersWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, request: MembersListRequest, request_options: options_mod.RequestOptions) !MembersListResponse {
    const query = try listQueryString(allocator, request);
    defer allocator.free(query);
    var prepared = try http.prepareRequest(allocator, config, .{ .method = .GET, .path = "/organization/members", .query = query }, request_options);
    defer prepared.deinit();
    var response = try transport.execute(allocator, prepared);
    defer response.deinit();
    return parseMembersListResponse(allocator, response);
}

pub fn parseMembersListResponse(allocator: std.mem.Allocator, response: http.HttpResponse) !MembersListResponse {
    if (errors.isErrorStatus(@backingInt(response.status))) return error.ApiError;
    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const parsed = try json.parseResponseLeaky(WireMembersListResponse, arena.allocator(), try arena.allocator().dupe(u8, response.body));
    return .{ .arena = arena, .data = parsed.data, .total_count = parsed.total_count };
}

fn listQueryString(allocator: std.mem.Allocator, request: MembersListRequest) ![]u8 {
    const offset_str = if (request.offset) |value| try std.fmt.allocPrint(allocator, "{d}", .{value}) else null;
    defer if (offset_str) |value| allocator.free(value);
    const limit_str = if (request.limit) |value| try std.fmt.allocPrint(allocator, "{d}", .{value}) else null;
    defer if (limit_str) |value| allocator.free(value);
    return query_mod.build(allocator, &.{
        .{ .name = "offset", .value = offset_str },
        .{ .name = "limit", .value = limit_str },
    });
}

test "organization members list serializes query params" {
    const query = try listQueryString(std.testing.allocator, .{ .offset = 5, .limit = 10 });
    defer std.testing.allocator.free(query);
    try std.testing.expectEqualStrings("offset=5&limit=10", query);
}

test "organization members list parses response" {
    var result = try listMembersWithTransport(std.testing.allocator, .{ .api_key = "test-key" }, http.FakeTransport{ .body = "{\"data\":[{\"id\":\"user_1\",\"email\":\"a@example.com\",\"first_name\":\"A\",\"last_name\":\"User\",\"role\":\"org:admin\"}],\"total_count\":1}" }, .{}, .{});
    defer result.deinit();
    try std.testing.expectEqual(@as(usize, 1), result.data.len);
    try std.testing.expectEqualStrings("org:admin", result.data[0].role.?);
}

test "organization members error status maps to ApiError" {
    try std.testing.expectError(error.ApiError, listMembersWithTransport(std.testing.allocator, .{ .api_key = "test-key" }, http.FakeTransport{ .status = .unauthorized, .body = "{}" }, .{}, .{}));
}

/// Organization settings require a management API key.
pub const Settings = struct {
    id: []const u8,
    is_filtered_model_catalog_enabled: bool,
};

pub const SettingsUpdateRequest = struct {
    /// Restricts authenticated model discovery to models the key can use.
    is_filtered_model_catalog_enabled: bool,
};

/// All returned strings and metadata are owned until `deinit`.
pub const SettingsResponse = struct {
    arena: std.heap.ArenaAllocator,
    data: Settings,
    response_metadata: http.ResponseMetadata,

    pub fn deinit(self: *SettingsResponse) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

pub fn getSettings(client: anytype, request_options: options_mod.RequestOptions) !SettingsResponse {
    return getSettingsWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, request_options);
}

pub fn getSettingsWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, request_options: options_mod.RequestOptions) !SettingsResponse {
    return executeSettings(allocator, config, transport, .{ .method = .GET, .path = "/organization/settings" }, request_options);
}

pub fn updateSettings(client: anytype, request: SettingsUpdateRequest, request_options: options_mod.RequestOptions) !SettingsResponse {
    return updateSettingsWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, request, request_options);
}

pub fn updateSettingsWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, request: SettingsUpdateRequest, request_options: options_mod.RequestOptions) !SettingsResponse {
    const body = try json.stringifyRequest(allocator, request);
    defer allocator.free(body);
    return executeSettings(allocator, config, transport, .{ .method = .PATCH, .path = "/organization/settings", .body = body }, request_options);
}

fn executeSettings(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, request: http.HttpRequest, request_options: options_mod.RequestOptions) !SettingsResponse {
    var prepared = try http.prepareRequest(allocator, config, request, request_options);
    defer prepared.deinit();
    var response = try transport.execute(allocator, prepared);
    defer response.deinit();
    if (errors.isErrorStatus(@backingInt(response.status))) return error.ApiError;
    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const parsed = try json.parseResponseLeaky(struct { data: Settings }, arena.allocator(), try arena.allocator().dupe(u8, response.body));
    return .{ .arena = arena, .data = parsed.data, .response_metadata = try http.ResponseMetadata.fromHttpResponse(arena.allocator(), response) };
}

test "organization settings update sends false and owns its response" {
    const Transport = struct {
        pub fn execute(_: @This(), allocator: std.mem.Allocator, prepared: http.PreparedRequest) !http.HttpResponse {
            try std.testing.expectEqual(std.http.Method.PATCH, prepared.method);
            try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/organization/settings", prepared.url);
            try std.testing.expectEqualStrings("{\"is_filtered_model_catalog_enabled\":false}", prepared.body.?);
            return (http.FakeTransport{ .body = "{\"data\":{\"id\":\"org_1\",\"is_filtered_model_catalog_enabled\":false,\"future\":true}}", .headers = &.{.{ .name = "x-request-id", .value = "req_settings" }} }).execute(allocator, prepared);
        }
    };
    var result = try updateSettingsWithTransport(std.testing.allocator, .{ .api_key = "test" }, Transport{}, .{ .is_filtered_model_catalog_enabled = false }, .{});
    defer result.deinit();
    try std.testing.expect(!result.data.is_filtered_model_catalog_enabled);
    try std.testing.expectEqualStrings("org_1", result.data.id);
    try std.testing.expectEqualStrings("req_settings", result.response_metadata.request_id.?);
}

test "organization settings get validates wire shape and maps errors" {
    const Transport = struct {
        pub fn execute(_: @This(), allocator: std.mem.Allocator, prepared: http.PreparedRequest) !http.HttpResponse {
            try std.testing.expectEqual(std.http.Method.GET, prepared.method);
            try std.testing.expect(prepared.body == null);
            return (http.FakeTransport{ .body = "{\"data\":{\"id\":\"org_1\",\"is_filtered_model_catalog_enabled\":true}}" }).execute(allocator, prepared);
        }
    };
    var result = try getSettingsWithTransport(std.testing.allocator, .{ .api_key = "test" }, Transport{}, .{});
    defer result.deinit();
    try std.testing.expect(result.data.is_filtered_model_catalog_enabled);
    try std.testing.expectError(error.MissingField, getSettingsWithTransport(std.testing.allocator, .{ .api_key = "test" }, http.FakeTransport{ .body = "{\"data\":{\"id\":\"org_1\"}}" }, .{}));
    try std.testing.expectError(error.ApiError, getSettingsWithTransport(std.testing.allocator, .{ .api_key = "test" }, http.FakeTransport{ .status = .forbidden, .body = "{}" }, .{}));
    try std.testing.expectError(error.ApiError, updateSettingsWithTransport(std.testing.allocator, .{ .api_key = "test" }, http.FakeTransport{ .status = .unauthorized }, .{ .is_filtered_model_catalog_enabled = true }, .{}));
}
