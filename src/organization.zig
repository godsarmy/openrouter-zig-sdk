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
    if (errors.isErrorStatus(@intFromEnum(response.status))) return error.ApiError;
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
