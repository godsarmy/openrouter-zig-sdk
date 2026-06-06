//! Auth keys API.

const std = @import("std");

const config_mod = @import("config.zig");
const errors = @import("errors.zig");
const http = @import("http.zig");
const json = @import("json.zig");
const options_mod = @import("options.zig");

pub const CreateCodeRequest = struct {
    callback_url: []const u8,
    code_challenge: []const u8,
    code_challenge_method: []const u8,
    limit: ?f64 = null,
};

pub const ExchangeRequest = struct {
    code: []const u8,
    code_challenge_method: []const u8,
    code_verifier: []const u8,
};

pub const AuthorizationCode = struct {
    app_id: i64,
    created_at: []const u8,
    id: []const u8,
};

pub const CreateCodeResponse = struct {
    arena: std.heap.ArenaAllocator,
    data: AuthorizationCode,

    pub fn deinit(self: *CreateCodeResponse) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

pub const ExchangeResponse = struct {
    arena: std.heap.ArenaAllocator,
    key: []const u8,
    user_id: []const u8,

    pub fn deinit(self: *ExchangeResponse) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

const WireCreateCodeResponse = struct { data: AuthorizationCode };
const WireExchangeResponse = struct { key: []const u8, user_id: []const u8 };

pub fn createCode(client: anytype, request: CreateCodeRequest, request_options: options_mod.RequestOptions) !CreateCodeResponse {
    const body = try json.stringifyRequest(client.allocator, request);
    defer client.allocator.free(body);
    var prepared = try http.prepareRequest(client.allocator, client.config, .{ .method = .POST, .path = "/auth/keys/code", .body = body }, request_options);
    defer prepared.deinit();
    var response = try http.execute(client.allocator, &client.http_client, prepared);
    defer response.deinit();
    return parseCreateCodeResponse(client.allocator, response);
}

pub fn createCodeWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, request: CreateCodeRequest, request_options: options_mod.RequestOptions) !CreateCodeResponse {
    const body = try json.stringifyRequest(allocator, request);
    defer allocator.free(body);
    var prepared = try http.prepareRequest(allocator, config, .{ .method = .POST, .path = "/auth/keys/code", .body = body }, request_options);
    defer prepared.deinit();
    var response = try transport.execute(allocator, prepared);
    defer response.deinit();
    return parseCreateCodeResponse(allocator, response);
}

pub fn exchange(client: anytype, request: ExchangeRequest, request_options: options_mod.RequestOptions) !ExchangeResponse {
    const body = try json.stringifyRequest(client.allocator, request);
    defer client.allocator.free(body);
    var prepared = try http.prepareRequest(client.allocator, client.config, .{ .method = .POST, .path = "/auth/keys", .body = body }, request_options);
    defer prepared.deinit();
    var response = try http.execute(client.allocator, &client.http_client, prepared);
    defer response.deinit();
    return parseExchangeResponse(client.allocator, response);
}

pub fn exchangeWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, request: ExchangeRequest, request_options: options_mod.RequestOptions) !ExchangeResponse {
    const body = try json.stringifyRequest(allocator, request);
    defer allocator.free(body);
    var prepared = try http.prepareRequest(allocator, config, .{ .method = .POST, .path = "/auth/keys", .body = body }, request_options);
    defer prepared.deinit();
    var response = try transport.execute(allocator, prepared);
    defer response.deinit();
    return parseExchangeResponse(allocator, response);
}

pub fn parseCreateCodeResponse(allocator: std.mem.Allocator, response: http.HttpResponse) !CreateCodeResponse {
    if (errors.isErrorStatus(@intFromEnum(response.status))) return error.ApiError;
    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const parsed = try json.parseResponseLeaky(WireCreateCodeResponse, arena.allocator(), try arena.allocator().dupe(u8, response.body));
    return .{ .arena = arena, .data = parsed.data };
}

pub fn parseExchangeResponse(allocator: std.mem.Allocator, response: http.HttpResponse) !ExchangeResponse {
    if (errors.isErrorStatus(@intFromEnum(response.status))) return error.ApiError;
    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const parsed = try json.parseResponseLeaky(WireExchangeResponse, arena.allocator(), try arena.allocator().dupe(u8, response.body));
    return .{ .arena = arena, .key = parsed.key, .user_id = parsed.user_id };
}

test "auth keys createCode parses response" {
    const response_body =
        \\{"data":{"app_id":123,"created_at":"2026-06-06T00:00:00Z","id":"code_abc"}}
    ;
    var result = try createCodeWithTransport(std.testing.allocator, .{ .api_key = "test-key" }, http.FakeTransport{ .body = response_body }, .{
        .callback_url = "https://example.com/callback",
        .code_challenge = "challenge",
        .code_challenge_method = "S256",
        .limit = 10,
    }, .{});
    defer result.deinit();

    try std.testing.expectEqual(@as(i64, 123), result.data.app_id);
    try std.testing.expectEqualStrings("code_abc", result.data.id);
}

test "auth keys exchange parses response" {
    const response_body =
        \\{"key":"sk-or-v1-abc","user_id":"user_123"}
    ;
    var result = try exchangeWithTransport(std.testing.allocator, .{ .api_key = "test-key" }, http.FakeTransport{ .body = response_body }, .{
        .code = "code_abc",
        .code_challenge_method = "S256",
        .code_verifier = "verifier",
    }, .{});
    defer result.deinit();

    try std.testing.expectEqualStrings("sk-or-v1-abc", result.key);
    try std.testing.expectEqualStrings("user_123", result.user_id);
}

test "auth keys createCode sends POST /auth/keys/code" {
    const body = try json.stringifyRequest(std.testing.allocator, CreateCodeRequest{
        .callback_url = "https://example.com/callback",
        .code_challenge = "challenge",
        .code_challenge_method = "S256",
    });
    defer std.testing.allocator.free(body);

    var prepared = try http.prepareRequest(std.testing.allocator, .{ .api_key = "test-key" }, .{ .method = .POST, .path = "/auth/keys/code", .body = body }, .{});
    defer prepared.deinit();

    try std.testing.expectEqual(std.http.Method.POST, prepared.method);
    try std.testing.expectEqualStrings(body, prepared.body.?);
}
