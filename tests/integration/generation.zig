const std = @import("std");
const openrouter = @import("openrouter");
const support = @import("support.zig");

test "generation integration" {
    try support.requireProfile(.standard);
    var threaded: std.Io.Threaded = .init_single_threaded;
    defer threaded.deinit();

    const generation_id = support.env("OPENROUTER_GENERATION_ID") orelse return error.SkipZigTest;
    var client = try support.initPublicClient(&threaded);
    defer client.deinit();

    var response = try client.generation.get(.{ .id = generation_id }, .{});
    defer response.deinit();

    try std.testing.expect(response.data.id.len > 0);
}

test "generation content integration" {
    try support.requireProfile(.standard);
    var threaded: std.Io.Threaded = .init_single_threaded;
    defer threaded.deinit();

    const generation_id = support.env("OPENROUTER_GENERATION_ID") orelse return error.SkipZigTest;
    var client = try support.initPublicClient(&threaded);
    defer client.deinit();

    var response = try client.generation.content(.{ .id = generation_id }, .{});
    defer response.deinit();

    try std.testing.expect(response.data.input.prompt != null or response.data.input.messages != null);
}

/// Poll metadata for the completion we already made; never repeat inference.
/// ApiError lacks a status here, so every unsuccessful bounded poll remains a
/// failure if the record does not become readable. Parsing errors fail at once.
pub fn waitForMetadata(client: *openrouter.Client, io: std.Io, id: []const u8) !openrouter.GenerationGetResponse {
    const delays = [_]i64{ 2, 4, 8 };
    var attempt: usize = 0;
    while (true) : (attempt += 1) {
        return client.generation.get(.{ .id = id }, .{}) catch |err| {
            if (err != error.ApiError or attempt == delays.len) return err;
            try std.Io.sleep(io, .fromSeconds(delays[attempt]), .awake);
            continue;
        };
    }
}
