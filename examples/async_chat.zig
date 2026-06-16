const std = @import("std");
const openrouter = @import("openrouter");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const api_key = init.minimal.environ.getAlloc(allocator, "OPENROUTER_API_KEY") catch null orelse {
        std.debug.print("Set OPENROUTER_API_KEY to run this example.\n", .{});
        return;
    };
    defer allocator.free(api_key);

    // `Client` is not thread-safe; use one client per concurrent task.
    var first = init.io.concurrent(fetchAnswer, .{
        allocator,
        init.io,
        api_key,
        "Answer in one short sentence: what is Zig good at?",
    }) catch |err| switch (err) {
        error.ConcurrencyUnavailable => {
            std.debug.print("This I/O backend does not support concurrency.\n", .{});
            return;
        },
    };
    var first_pending = true;
    defer if (first_pending) {
        if (first.cancel(init.io)) |answer| allocator.free(answer) else |_| {}
    };

    var second = init.io.concurrent(fetchAnswer, .{
        allocator,
        init.io,
        api_key,
        "Answer in one short sentence: what makes OpenRouter useful?",
    }) catch |err| switch (err) {
        error.ConcurrencyUnavailable => {
            std.debug.print("This I/O backend does not support concurrency.\n", .{});
            return;
        },
    };
    var second_pending = true;
    defer if (second_pending) {
        if (second.cancel(init.io)) |answer| allocator.free(answer) else |_| {}
    };

    const first_result = first.await(init.io);
    first_pending = false;
    const first_answer = try first_result;
    defer allocator.free(first_answer);

    const second_result = second.await(init.io);
    second_pending = false;
    const second_answer = try second_result;
    defer allocator.free(second_answer);

    std.debug.print("First answer: {s}\n", .{first_answer});
    std.debug.print("Second answer: {s}\n", .{second_answer});
}

fn fetchAnswer(
    allocator: std.mem.Allocator,
    io: std.Io,
    api_key: []const u8,
    prompt: []const u8,
) ![]u8 {
    var client = try openrouter.Client.init(allocator, io, .{
        .api_key = api_key,
        .http_referer = "https://github.com/godsarmy/openrouter-zig-sdk",
        .x_title = "openrouter-zig async example",
    });
    defer client.deinit();

    var response = try client.chat.completions.create(.{
        .model = "openai/gpt-4o-mini",
        .messages = &.{
            .{ .role = .user, .content = .{ .text = prompt } },
        },
    }, .{});
    defer response.deinit();

    const content = response.choices[0].message.content orelse return error.MissingContent;
    return try allocator.dupe(u8, content);
}
