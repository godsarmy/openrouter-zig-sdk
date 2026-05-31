//! JSON encoding and decoding helpers.

const std = @import("std");

pub fn Parsed(comptime T: type) type {
    return std.json.Parsed(T);
}

pub fn stringifyRequest(allocator: std.mem.Allocator, value: anytype) ![]u8 {
    var out: std.Io.Writer.Allocating = .init(allocator);
    errdefer out.deinit();

    try std.json.Stringify.value(value, .{
        .emit_null_optional_fields = false,
    }, &out.writer);

    return try out.toOwnedSlice();
}

pub fn parseResponse(comptime T: type, allocator: std.mem.Allocator, body: []const u8) !Parsed(T) {
    return std.json.parseFromSlice(T, allocator, body, .{
        .ignore_unknown_fields = true,
    });
}

pub fn parseResponseLeaky(comptime T: type, arena: std.mem.Allocator, body: []const u8) !T {
    return std.json.parseFromSliceLeaky(T, arena, body, .{
        .ignore_unknown_fields = true,
    });
}

pub fn enumString(comptime value: anytype) []const u8 {
    return @tagName(value);
}

test "stringifyRequest omits null optional fields" {
    const Request = struct {
        model: []const u8,
        temperature: ?f32 = null,
    };

    const body = try stringifyRequest(std.testing.allocator, Request{ .model = "openai/gpt-4o-mini" });
    defer std.testing.allocator.free(body);

    try std.testing.expectEqualStrings(
        "{\"model\":\"openai/gpt-4o-mini\"}",
        body,
    );
}

test "stringifyRequest includes present optional fields" {
    const Request = struct {
        model: []const u8,
        temperature: ?f32 = null,
    };

    const body = try stringifyRequest(std.testing.allocator, Request{
        .model = "openai/gpt-4o-mini",
        .temperature = 0.5,
    });
    defer std.testing.allocator.free(body);

    try std.testing.expect(std.mem.indexOf(u8, body, "\"temperature\":") != null);
}

test "parseResponse ignores unknown response fields" {
    const Response = struct {
        id: []const u8,
    };

    var parsed = try parseResponse(Response, std.testing.allocator, "{\"id\":\"abc\",\"extra\":123}");
    defer parsed.deinit();

    try std.testing.expectEqualStrings("abc", parsed.value.id);
}

test "parseResponse returns clear invalid JSON error" {
    const Response = struct { id: []const u8 };

    try std.testing.expectError(error.UnexpectedEndOfInput, parseResponse(Response, std.testing.allocator, "{"));
}

test "parseResponseLeaky parses into caller arena" {
    const Response = struct { id: []const u8 };

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const parsed = try parseResponseLeaky(Response, arena.allocator(), "{\"id\":\"abc\",\"extra\":123}");
    try std.testing.expectEqualStrings("abc", parsed.id);
}

test "enumString returns enum tag names" {
    const Role = enum { system, user };
    try std.testing.expectEqualStrings("user", enumString(Role.user));
}
