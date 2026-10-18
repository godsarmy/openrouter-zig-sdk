//! Internal helpers shared by enterprise and specialized resources.
const std = @import("std");
const config_mod = @import("config.zig");
const http = @import("http.zig");
const json = @import("json.zig");
const options = @import("options.zig");

/// Wrap in an optional to distinguish omission from an explicit JSON null.
pub fn Nullable(comptime T: type) type {
    return union(enum) {
        value: T,
        clear,
        pub fn jsonStringify(self: @This(), writer: anytype) !void {
            switch (self) {
                .value => |v| try writer.write(v),
                .clear => try writer.write(null),
            }
        }
    };
}

pub fn Response(comptime T: type) type {
    return struct {
        pub const Payload = T;
        arena: std.heap.ArenaAllocator,
        /// Decoded wire payload, owned with metadata until `deinit`.
        value: T,
        response_metadata: http.ResponseMetadata,
        pub fn deinit(self: *@This()) void {
            self.arena.deinit();
            self.* = undefined;
        }
    };
}

pub fn execute(comptime T: type, allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, request: http.HttpRequest, request_options: options.RequestOptions) !Response(T) {
    var prepared = try http.prepareRequest(allocator, config, request, request_options);
    defer prepared.deinit();
    var response = try transport.execute(allocator, prepared);
    defer response.deinit();
    if (@backingInt(response.status) >= 400) return error.ApiError;
    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const a = arena.allocator();
    const value = if (T == void) {} else try json.parseResponseLeaky(T, a, try a.dupe(u8, response.body));
    const metadata = try http.ResponseMetadata.fromHttpResponse(a, response);
    return .{ .arena = arena, .value = value, .response_metadata = metadata };
}

/// Encode each dynamic path component separately. Reject dot traversal and
/// empty identifiers before transport execution.
pub fn segment(allocator: std.mem.Allocator, value: []const u8) ![]u8 {
    if (value.len == 0 or std.mem.eql(u8, value, ".") or std.mem.eql(u8, value, "..")) return error.InvalidPath;
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    const hex = "0123456789ABCDEF";
    for (value) |byte| {
        if (std.ascii.isAlphanumeric(byte) or byte == '-' or byte == '_' or byte == '.' or byte == '~') {
            try out.append(allocator, byte);
        } else {
            try out.appendSlice(allocator, &.{ '%', hex[byte >> 4], hex[byte & 15] });
        }
    }
    return out.toOwnedSlice(allocator);
}

test "path segments reject traversal and percent encode literal escapes" {
    for ([_][]const u8{ "", ".", ".." }) |v| try std.testing.expectError(error.InvalidPath, segment(std.testing.allocator, v));
    const path = try segment(std.testing.allocator, "%2e%2e/a?#");
    defer std.testing.allocator.free(path);
    try std.testing.expectEqualStrings("%252e%252e%2Fa%3F%23", path);
}
