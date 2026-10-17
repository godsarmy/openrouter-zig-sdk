//! Private endpoint discovery. Requires a management key and private-endpoint entitlement.
const std = @import("std");
const config_mod = @import("config.zig");
const errors = @import("errors.zig");
const http = @import("http.zig");
const json = @import("json.zig");
const options_mod = @import("options.zig");

pub const Summary = struct {
    id: []const u8,
    /// Preserved as a string to allow future server lifecycle states.
    status: []const u8,
    model_permaslug: []const u8,
    model_slug: ?[]const u8,
    model_name: ?[]const u8,
    provider_name: []const u8,
    created_at: []const u8,
};

pub const Pricing = struct {
    /// USD per token, preserved as decimal strings.
    prompt: []const u8,
    completion: []const u8,
};

pub const Endpoint = struct {
    id: []const u8,
    status: []const u8,
    model_permaslug: []const u8,
    model_slug: ?[]const u8,
    model_name: ?[]const u8,
    provider_name: []const u8,
    provider_slug: ?[]const u8,
    base_url: ?[]const u8,
    upstream_model_id: []const u8,
    declared_zdr: ?bool,
    /// Known values are global, europe, and us; preserves future values.
    declared_region: ?[]const u8,
    pricing: Pricing,
};

pub const ListResponse = OwnedResponse([]Summary);
pub const GetResponse = OwnedResponse(Endpoint);

fn OwnedResponse(comptime T: type) type {
    return struct {
        /// All data and metadata are owned until `deinit`.
        arena: std.heap.ArenaAllocator,
        data: T,
        response_metadata: http.ResponseMetadata,

        pub fn deinit(self: *@This()) void {
            self.arena.deinit();
            self.* = undefined;
        }
    };
}

pub fn list(client: anytype, request_options: options_mod.RequestOptions) !ListResponse {
    return listWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, request_options);
}

pub fn listWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, request_options: options_mod.RequestOptions) !ListResponse {
    return read([]Summary, allocator, config, transport, "/private-endpoints", request_options);
}

pub fn get(client: anytype, id: []const u8, request_options: options_mod.RequestOptions) !GetResponse {
    return getWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, id, request_options);
}

pub fn getWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, id: []const u8, request_options: options_mod.RequestOptions) !GetResponse {
    if (id.len == 0 or std.mem.eql(u8, id, ".") or std.mem.eql(u8, id, "..")) return error.InvalidPath;
    var buffer: std.ArrayList(u8) = .empty;
    defer buffer.deinit(allocator);
    try buffer.appendSlice(allocator, "/private-endpoints/");
    const hex = "0123456789ABCDEF";
    for (id) |byte| {
        if (std.ascii.isAlphanumeric(byte) or byte == '-' or byte == '_' or byte == '.' or byte == '~') {
            try buffer.append(allocator, byte);
        } else {
            try buffer.appendSlice(allocator, &.{ '%', hex[byte >> 4], hex[byte & 0x0F] });
        }
    }
    const path = try buffer.toOwnedSlice(allocator);
    defer allocator.free(path);
    return read(Endpoint, allocator, config, transport, path, request_options);
}

fn read(comptime T: type, allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, path: []const u8, request_options: options_mod.RequestOptions) !OwnedResponse(T) {
    var prepared = try http.prepareRequest(allocator, config, .{ .method = .GET, .path = path }, request_options);
    defer prepared.deinit();
    var response = try transport.execute(allocator, prepared);
    defer response.deinit();
    if (errors.isErrorStatus(@backingInt(response.status))) return error.ApiError;
    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const parsed = try json.parseResponseLeaky(struct { data: T }, arena.allocator(), try arena.allocator().dupe(u8, response.body));
    return .{ .arena = arena, .data = parsed.data, .response_metadata = try http.ResponseMetadata.fromHttpResponse(arena.allocator(), response) };
}

test "private endpoint detail escapes identifiers and preserves response data" {
    const Transport = struct {
        pub fn execute(_: @This(), allocator: std.mem.Allocator, prepared: http.PreparedRequest) !http.HttpResponse {
            try std.testing.expectEqual(std.http.Method.GET, prepared.method);
            try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/private-endpoints/a%2Fb%3Fc%23d", prepared.url);
            try std.testing.expect(prepared.body == null);
            return (http.FakeTransport{ .body = "{\"data\":{\"base_url\":\"https://contoso.openai.azure.com\",\"declared_region\":\"us\",\"declared_zdr\":true,\"id\":\"5b1c4c4e-7d0a-4a8e-9f3a-2d6c1b0e8a11\",\"model_name\":\"OpenAI: GPT-4o\",\"model_permaslug\":\"openai/gpt-4o-2024-08-06\",\"model_slug\":\"openai/gpt-4o\",\"pricing\":{\"completion\":\"0.00001\",\"prompt\":\"0.0000025\"},\"provider_name\":\"Azure\",\"provider_slug\":\"azure\",\"status\":\"active\",\"upstream_model_id\":\"gpt-4o-prod\"}}", .headers = &.{.{ .name = "x-request-id", .value = "req_private" }} }).execute(allocator, prepared);
        }
    };
    var result = try getWithTransport(std.testing.allocator, .{ .api_key = "test" }, Transport{}, "a/b?c#d", .{});
    defer result.deinit();
    try std.testing.expectEqualStrings("0.0000025", result.data.pricing.prompt);
    try std.testing.expectEqualStrings("us", result.data.declared_region.?);
    try std.testing.expect(result.data.declared_zdr.?);
    try std.testing.expectEqualStrings("req_private", result.response_metadata.request_id.?);
}

test "private endpoint list preserves future states and unlisted models" {
    const Transport = struct {
        pub fn execute(_: @This(), allocator: std.mem.Allocator, prepared: http.PreparedRequest) !http.HttpResponse {
            try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/private-endpoints", prepared.url);
            return (http.FakeTransport{ .body = "{\"data\":[{\"id\":\"ep_1\",\"status\":\"future\",\"model_permaslug\":\"vendor/model\",\"model_slug\":null,\"model_name\":null,\"provider_name\":\"Provider\",\"created_at\":\"2026-10-17T00:00:00Z\",\"extra\":true}]}" }).execute(allocator, prepared);
        }
    };
    var result = try listWithTransport(std.testing.allocator, .{ .api_key = "test" }, Transport{}, .{});
    defer result.deinit();
    try std.testing.expectEqual(@as(usize, 1), result.data.len);
    try std.testing.expectEqualStrings("future", result.data[0].status);
    try std.testing.expect(result.data[0].model_slug == null);
}

test "private endpoint reads reject invalid shapes and map access errors" {
    const config: config_mod.Config = .{ .api_key = "test" };
    var empty = try listWithTransport(std.testing.allocator, config, http.FakeTransport{ .body = "{\"data\":[]}" }, .{});
    defer empty.deinit();
    try std.testing.expectEqual(@as(usize, 0), empty.data.len);
    try std.testing.expectError(error.MissingField, getWithTransport(std.testing.allocator, config, http.FakeTransport{ .body = "{\"data\":{}}" }, "ep_1", .{}));
    try std.testing.expectError(error.ApiError, listWithTransport(std.testing.allocator, config, http.FakeTransport{ .status = .forbidden }, .{}));
    try std.testing.expectError(error.ApiError, getWithTransport(std.testing.allocator, config, http.FakeTransport{ .status = .not_found }, "ep_1", .{}));
    for ([_][]const u8{ "", ".", ".." }) |id| {
        try std.testing.expectError(error.InvalidPath, getWithTransport(std.testing.allocator, config, http.FakeTransport{}, id, .{}));
    }
}
