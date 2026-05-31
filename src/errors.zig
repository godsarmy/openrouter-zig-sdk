//! API and transport error handling.

const std = @import("std");

const http_mod = @import("http.zig");

pub const Error = error{
    ApiError,
    OutOfMemory,
};

pub const StatusKind = enum {
    success,
    bad_request,
    unauthorized,
    payment_required,
    not_found,
    request_timeout,
    payload_too_large,
    unprocessable_entity,
    rate_limited,
    internal_server_error,
    bad_gateway,
    service_unavailable,
    timeout,
    overloaded,
    client_error,
    server_error,
    unknown,
};

pub const ApiError = struct {
    arena: std.heap.ArenaAllocator,
    status: u16,
    code: ?[]const u8 = null,
    message: []const u8,
    raw_body: []const u8,
    request_id: ?[]const u8 = null,

    pub fn deinit(self: *ApiError) void {
        self.arena.deinit();
        self.* = undefined;
    }

    pub fn kind(self: ApiError) StatusKind {
        return classifyStatus(self.status);
    }

    pub fn retryable(self: ApiError) bool {
        return isRetryableStatus(self.status);
    }
};

pub fn classifyStatus(status: u16) StatusKind {
    if (status >= 200 and status <= 299) return .success;
    return switch (status) {
        400 => .bad_request,
        401 => .unauthorized,
        402 => .payment_required,
        404 => .not_found,
        408 => .request_timeout,
        413 => .payload_too_large,
        422 => .unprocessable_entity,
        429 => .rate_limited,
        500 => .internal_server_error,
        502 => .bad_gateway,
        503 => .service_unavailable,
        524 => .timeout,
        529 => .overloaded,
        else => if (status >= 400 and status <= 499)
            .client_error
        else if (status >= 500 and status <= 599)
            .server_error
        else
            .unknown,
    };
}

pub fn isRetryableStatus(status: u16) bool {
    return switch (status) {
        429, 500, 502, 503, 524, 529 => true,
        else => false,
    };
}

pub fn isErrorStatus(status: u16) bool {
    return status >= 400;
}

pub fn buildApiError(allocator: std.mem.Allocator, response: http_mod.HttpResponse) !ApiError {
    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const arena_allocator = arena.allocator();

    var code: ?[]const u8 = null;
    var message: ?[]const u8 = null;

    if (std.json.parseFromSliceLeaky(std.json.Value, arena_allocator, response.body, .{})) |value| {
        extractErrorFields(arena_allocator, value, &code, &message) catch {};
    } else |_| {}

    const fallback_message = try std.fmt.allocPrint(arena_allocator, "OpenRouter API error {d}", .{@intFromEnum(response.status)});

    return .{
        .arena = arena,
        .status = @intFromEnum(response.status),
        .code = code,
        .message = message orelse fallback_message,
        .raw_body = try arena_allocator.dupe(u8, response.body),
        .request_id = if (response.request_id) |value| try arena_allocator.dupe(u8, value) else null,
    };
}

fn extractErrorFields(
    allocator: std.mem.Allocator,
    value: std.json.Value,
    code: *?[]const u8,
    message: *?[]const u8,
) !void {
    const object = switch (value) {
        .object => |object| object,
        else => return,
    };

    if (object.get("error")) |error_value| {
        switch (error_value) {
            .object => |error_object| {
                if (error_object.get("code")) |code_value| code.* = try copyValueAsString(allocator, code_value);
                if (error_object.get("message")) |message_value| message.* = try copyValueAsString(allocator, message_value);
            },
            .string => |text| message.* = try allocator.dupe(u8, text),
            else => {},
        }
    }

    if (message.* == null) {
        if (object.get("message")) |message_value| message.* = try copyValueAsString(allocator, message_value);
    }
    if (code.* == null) {
        if (object.get("code")) |code_value| code.* = try copyValueAsString(allocator, code_value);
    }
}

fn copyValueAsString(allocator: std.mem.Allocator, value: std.json.Value) !?[]const u8 {
    return switch (value) {
        .string => |text| try allocator.dupe(u8, text),
        .integer => |number| try std.fmt.allocPrint(allocator, "{d}", .{number}),
        .float => |number| try std.fmt.allocPrint(allocator, "{d}", .{number}),
        .number_string => |text| try allocator.dupe(u8, text),
        else => null,
    };
}

test "classifies known API statuses" {
    try std.testing.expectEqual(StatusKind.unauthorized, classifyStatus(401));
    try std.testing.expectEqual(StatusKind.rate_limited, classifyStatus(429));
    try std.testing.expectEqual(StatusKind.timeout, classifyStatus(524));
    try std.testing.expectEqual(StatusKind.overloaded, classifyStatus(529));
    try std.testing.expectEqual(StatusKind.client_error, classifyStatus(418));
    try std.testing.expectEqual(StatusKind.server_error, classifyStatus(599));
}

test "detects retryable API statuses" {
    try std.testing.expect(isRetryableStatus(429));
    try std.testing.expect(isRetryableStatus(500));
    try std.testing.expect(isRetryableStatus(502));
    try std.testing.expect(isRetryableStatus(503));
    try std.testing.expect(isRetryableStatus(524));
    try std.testing.expect(isRetryableStatus(529));
    try std.testing.expect(!isRetryableStatus(400));
    try std.testing.expect(!isRetryableStatus(401));
}

test "parses OpenRouter nested error JSON" {
    var response = http_mod.HttpResponse{
        .allocator = std.testing.allocator,
        .status = .unauthorized,
        .body = try std.testing.allocator.dupe(u8, "{\"error\":{\"code\":\"invalid_api_key\",\"message\":\"No auth\"}}"),
        .request_id = try std.testing.allocator.dupe(u8, "req_123"),
    };
    defer response.deinit();

    var api_error = try buildApiError(std.testing.allocator, response);
    defer api_error.deinit();

    try std.testing.expectEqual(@as(u16, 401), api_error.status);
    try std.testing.expectEqual(StatusKind.unauthorized, api_error.kind());
    try std.testing.expectEqualStrings("invalid_api_key", api_error.code.?);
    try std.testing.expectEqualStrings("No auth", api_error.message);
    try std.testing.expectEqualStrings(response.body, api_error.raw_body);
    try std.testing.expectEqualStrings("req_123", api_error.request_id.?);
}

test "preserves raw body for unknown error shape" {
    var response = http_mod.HttpResponse{
        .allocator = std.testing.allocator,
        .status = .bad_request,
        .body = try std.testing.allocator.dupe(u8, "not json"),
    };
    defer response.deinit();

    var api_error = try buildApiError(std.testing.allocator, response);
    defer api_error.deinit();

    try std.testing.expectEqual(@as(u16, 400), api_error.status);
    try std.testing.expectEqualStrings("OpenRouter API error 400", api_error.message);
    try std.testing.expectEqualStrings("not json", api_error.raw_body);
}

test "parses top-level error message and numeric code" {
    var response = http_mod.HttpResponse{
        .allocator = std.testing.allocator,
        .status = .too_many_requests,
        .body = try std.testing.allocator.dupe(u8, "{\"code\":429,\"message\":\"slow down\"}"),
    };
    defer response.deinit();

    var api_error = try buildApiError(std.testing.allocator, response);
    defer api_error.deinit();

    try std.testing.expect(api_error.retryable());
    try std.testing.expectEqualStrings("429", api_error.code.?);
    try std.testing.expectEqualStrings("slow down", api_error.message);
}
