//! URL query string helpers.

const std = @import("std");

pub const Param = struct {
    name: []const u8,
    value: ?[]const u8,
};

pub fn build(allocator: std.mem.Allocator, params: []const Param) ![]u8 {
    var query: std.ArrayList(u8) = .empty;
    errdefer query.deinit(allocator);

    for (params) |param| {
        try appendParam(allocator, &query, param.name, param.value);
    }

    return try query.toOwnedSlice(allocator);
}

pub fn single(allocator: std.mem.Allocator, name: []const u8, value: []const u8) ![]u8 {
    return build(allocator, &.{.{ .name = name, .value = value }});
}

fn appendParam(allocator: std.mem.Allocator, query: *std.ArrayList(u8), name: []const u8, value: ?[]const u8) !void {
    const payload = value orelse return;
    if (query.items.len > 0) try query.append(allocator, '&');
    try percentEncode(allocator, query, name);
    try query.append(allocator, '=');
    try percentEncode(allocator, query, payload);
}

fn percentEncode(allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: []const u8) !void {
    const hex = "0123456789ABCDEF";
    for (value) |byte| {
        if (std.ascii.isAlphanumeric(byte) or byte == '-' or byte == '_' or byte == '.' or byte == '~') {
            try output.append(allocator, byte);
        } else {
            try output.appendSlice(allocator, &.{ '%', hex[byte >> 4], hex[byte & 0x0F] });
        }
    }
}

test "build returns empty string for no params" {
    const result = try build(std.testing.allocator, &.{});
    defer std.testing.allocator.free(result);

    try std.testing.expectEqualStrings("", result);
}

test "build skips null params and escapes values" {
    const result = try build(std.testing.allocator, &.{
        .{ .name = "date", .value = "2025-08-24" },
        .{ .name = "ignored", .value = null },
        .{ .name = "api_key_hash", .value = "hash/with space" },
    });
    defer std.testing.allocator.free(result);

    try std.testing.expectEqualStrings("date=2025-08-24&api_key_hash=hash%2Fwith%20space", result);
}

test "single builds one escaped param" {
    const result = try single(std.testing.allocator, "id", "gen 123/abc");
    defer std.testing.allocator.free(result);

    try std.testing.expectEqualStrings("id=gen%20123%2Fabc", result);
}

test "build escapes param names" {
    const result = try build(std.testing.allocator, &.{.{ .name = "unsafe name", .value = "value" }});
    defer std.testing.allocator.free(result);

    try std.testing.expectEqualStrings("unsafe%20name=value", result);
}
