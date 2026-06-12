//! Observability destinations management API.

const std = @import("std");

const config_mod = @import("config.zig");
const errors = @import("errors.zig");
const http = @import("http.zig");
const json = @import("json.zig");
const options_mod = @import("options.zig");
const query_mod = @import("query.zig");

pub const DestinationConfig = std.json.Value;

pub const ListRequest = struct {
    offset: ?i64 = null,
    limit: ?i64 = null,
    workspace_id: ?[]const u8 = null,
};

pub const CreateRequest = struct {
    type: []const u8,
    name: []const u8,
    config: DestinationConfig,
    api_key_hashes: ?[]const []const u8 = null,
    enabled: ?bool = null,
    filter_rules: ?DestinationConfig = null,
    privacy_mode: ?bool = null,
    sampling_rate: ?f64 = null,
    workspace_id: ?[]const u8 = null,
};

pub const NullableJsonValue = union(enum) {
    null_value,
    value: DestinationConfig,

    pub fn jsonStringify(self: NullableJsonValue, jws: anytype) !void {
        switch (self) {
            .null_value => try jws.write(null),
            .value => |value| try jws.write(value),
        }
    }
};

pub const NullableStringList = union(enum) {
    null_value,
    values: []const []const u8,

    pub fn jsonStringify(self: NullableStringList, jws: anytype) !void {
        switch (self) {
            .null_value => try jws.write(null),
            .values => |value| try jws.write(value),
        }
    }
};

pub const UpdateRequest = struct {
    name: ?[]const u8 = null,
    config: ?DestinationConfig = null,
    api_key_hashes: ?NullableStringList = null,
    enabled: ?bool = null,
    filter_rules: ?NullableJsonValue = null,
    privacy_mode: ?bool = null,
    sampling_rate: ?f64 = null,
};

pub const Destination = struct {
    id: ?[]const u8 = null,
    type: ?[]const u8 = null,
    name: ?[]const u8 = null,
    config: ?DestinationConfig = null,
    api_key_hashes: ?[]const []const u8 = null,
    enabled: ?bool = null,
    filter_rules: ?DestinationConfig = null,
    privacy_mode: ?bool = null,
    sampling_rate: ?f64 = null,
    workspace_id: ?[]const u8 = null,
    created_at: ?[]const u8 = null,
    updated_at: ?[]const u8 = null,
};

pub const ListResponse = responseWithList(Destination);
pub const CreateResponse = responseWithData(Destination);
pub const GetResponse = responseWithData(Destination);
pub const UpdateResponse = responseWithData(Destination);

pub const DeleteResponse = struct {
    arena: std.heap.ArenaAllocator,
    deleted: bool,

    pub fn deinit(self: *DeleteResponse) void {
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

const WireListResponse = struct { data: []Destination, total_count: ?i64 = null };
const WireDataResponse = struct { data: Destination };
const WireDeleteResponse = struct { deleted: bool };

pub fn list(client: anytype, request: ListRequest, request_options: options_mod.RequestOptions) !ListResponse {
    return listWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, request, request_options);
}

pub fn listWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, request: ListRequest, request_options: options_mod.RequestOptions) !ListResponse {
    const query = try listQueryString(allocator, request);
    defer allocator.free(query);
    var response = try execute(allocator, config, transport, .{ .method = .GET, .path = "/observability/destinations", .query = query }, request_options);
    defer response.deinit();
    return parseListResponse(allocator, response);
}

pub fn create(client: anytype, request: CreateRequest, request_options: options_mod.RequestOptions) !CreateResponse {
    return createWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, request, request_options);
}

pub fn createWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, request: CreateRequest, request_options: options_mod.RequestOptions) !CreateResponse {
    const body = try json.stringifyRequest(allocator, request);
    defer allocator.free(body);
    var response = try execute(allocator, config, transport, .{ .method = .POST, .path = "/observability/destinations", .body = body }, request_options);
    defer response.deinit();
    return parseCreateResponse(allocator, response);
}

pub fn get(client: anytype, id: []const u8, request_options: options_mod.RequestOptions) !GetResponse {
    return getWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, id, request_options);
}

pub fn getWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, id: []const u8, request_options: options_mod.RequestOptions) !GetResponse {
    const path = try destinationPath(allocator, id);
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
    const path = try destinationPath(allocator, id);
    defer allocator.free(path);
    var response = try execute(allocator, config, transport, .{ .method = .PATCH, .path = path, .body = body }, request_options);
    defer response.deinit();
    return parseUpdateResponse(allocator, response);
}

pub fn delete(client: anytype, id: []const u8, request_options: options_mod.RequestOptions) !DeleteResponse {
    return deleteWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, id, request_options);
}

pub fn deleteWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, id: []const u8, request_options: options_mod.RequestOptions) !DeleteResponse {
    const path = try destinationPath(allocator, id);
    defer allocator.free(path);
    var response = try execute(allocator, config, transport, .{ .method = .DELETE, .path = path }, request_options);
    defer response.deinit();
    return parseDeleteResponse(allocator, response);
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

fn destinationPath(allocator: std.mem.Allocator, id: []const u8) ![]u8 {
    return std.fmt.allocPrint(allocator, "/observability/destinations/{s}", .{id});
}

test "observability list serializes query params" {
    const query = try listQueryString(std.testing.allocator, .{ .offset = 1, .limit = 20, .workspace_id = "ws_123" });
    defer std.testing.allocator.free(query);
    try std.testing.expectEqualStrings("offset=1&limit=20&workspace_id=ws_123", query);
}

test "observability create serializes request" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const config_value = try json.parseResponseLeaky(std.json.Value, arena.allocator(), "{\"url\":\"https://example.com/hook\"}");

    const body = try json.stringifyRequest(std.testing.allocator, CreateRequest{
        .type = "webhook",
        .name = "Alerts",
        .config = config_value,
        .enabled = true,
    });
    defer std.testing.allocator.free(body);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"type\":\"webhook\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"enabled\":true") != null);
}

test "observability update can serialize nullable filters" {
    const body = try json.stringifyRequest(std.testing.allocator, UpdateRequest{
        .name = "Alerts",
        .api_key_hashes = .null_value,
        .filter_rules = .null_value,
    });
    defer std.testing.allocator.free(body);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"api_key_hashes\":null") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"filter_rules\":null") != null);
}

test "observability list parses response" {
    var result = try listWithTransport(std.testing.allocator, .{ .api_key = "test-key" }, http.FakeTransport{ .body = "{\"data\":[{\"id\":\"dst_123\",\"name\":\"Alerts\",\"type\":\"webhook\"}],\"total_count\":1}" }, .{}, .{});
    defer result.deinit();
    try std.testing.expectEqual(@as(usize, 1), result.data.len);
    try std.testing.expectEqualStrings("dst_123", result.data[0].id.?);
}

test "observability create get update delete parse responses" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const config_value = try json.parseResponseLeaky(std.json.Value, arena.allocator(), "{\"url\":\"https://example.com/hook\"}");

    var created = try createWithTransport(std.testing.allocator, .{ .api_key = "test-key" }, http.FakeTransport{ .status = .created, .body = "{\"data\":{\"id\":\"dst_123\",\"name\":\"Alerts\",\"type\":\"webhook\"}}" }, .{ .type = "webhook", .name = "Alerts", .config = config_value }, .{});
    defer created.deinit();
    try std.testing.expectEqualStrings("dst_123", created.data.id.?);

    var got = try getWithTransport(std.testing.allocator, .{ .api_key = "test-key" }, http.FakeTransport{ .body = "{\"data\":{\"id\":\"dst_123\",\"name\":\"Alerts\"}}" }, "dst_123", .{});
    defer got.deinit();
    try std.testing.expectEqualStrings("Alerts", got.data.name.?);

    var updated = try updateWithTransport(std.testing.allocator, .{ .api_key = "test-key" }, http.FakeTransport{ .body = "{\"data\":{\"id\":\"dst_123\",\"name\":\"Updated\"}}" }, "dst_123", .{ .name = "Updated" }, .{});
    defer updated.deinit();
    try std.testing.expectEqualStrings("Updated", updated.data.name.?);

    var deleted = try deleteWithTransport(std.testing.allocator, .{ .api_key = "test-key" }, http.FakeTransport{ .body = "{\"deleted\":true}" }, "dst_123", .{});
    defer deleted.deinit();
    try std.testing.expect(deleted.deleted);
}

test "observability paths and errors" {
    const path = try destinationPath(std.testing.allocator, "dst_123");
    defer std.testing.allocator.free(path);
    try std.testing.expectEqualStrings("/observability/destinations/dst_123", path);
    try std.testing.expectError(error.ApiError, listWithTransport(std.testing.allocator, .{ .api_key = "test-key" }, http.FakeTransport{ .status = .forbidden, .body = "{}" }, .{}, .{}));
}
