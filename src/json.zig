//! JSON encoding and decoding compile spike.

const std = @import("std");

test "compile spike: stringify omits null optional fields" {
    const Request = struct {
        model: []const u8,
        temperature: ?f32 = null,
    };

    var out: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer out.deinit();

    try std.json.Stringify.value(Request{ .model = "openai/gpt-4o-mini" }, .{
        .emit_null_optional_fields = false,
    }, &out.writer);

    try std.testing.expectEqualStrings(
        "{\"model\":\"openai/gpt-4o-mini\"}",
        out.written(),
    );
}

test "compile spike: parse ignores unknown response fields" {
    const Response = struct {
        id: []const u8,
    };

    var parsed = try std.json.parseFromSlice(Response, std.testing.allocator, "{\"id\":\"abc\",\"extra\":123}", .{
        .ignore_unknown_fields = true,
    });
    defer parsed.deinit();

    try std.testing.expectEqualStrings("abc", parsed.value.id);
}
