const std = @import("std");
const openrouter = @import("openrouter");

pub fn main(init: std.process.Init) !void {
    var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
    defer _ = debug_allocator.deinit();
    const allocator = debug_allocator.allocator();

    const api_key = init.minimal.environ.getAlloc(allocator, "OPENROUTER_API_KEY") catch null orelse {
        std.debug.print("Set OPENROUTER_API_KEY to run this example.\n", .{});
        return;
    };
    defer allocator.free(api_key);

    var client = try openrouter.Client.init(allocator, init.io, .{
        .api_key = api_key,
        .http_referer = "https://github.com/godsarmy/openrouter-zig-sdk",
        .x_title = "openrouter-zig example",
    });
    defer client.deinit();

    const messages = &.{openrouter.ChatMessage{
        .role = .user,
        .content = .{ .text = "Write one short sentence about Zig." },
    }};

    var response = try client.chat.completions.stream(.{
        .model = "openai/gpt-4o-mini",
        .messages = messages,
    }, .{});
    defer response.deinit();

    while (try response.next()) |chunk| {
        // `chunk` owns an arena-backed payload; deinitialize it once after use.
        var owned_chunk = chunk;
        defer owned_chunk.deinit();
        if (owned_chunk.content()) |content| {
            std.debug.print("{s}", .{content});
        }
    }
    std.debug.print("\n", .{});
}
