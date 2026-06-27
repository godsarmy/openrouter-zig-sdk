const std = @import("std");
const openrouter = @import("openrouter");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const api_key = init.minimal.environ.getAlloc(allocator, "OPENROUTER_API_KEY") catch return error.MissingApiKey;
    defer allocator.free(api_key);

    const workspace_id = init.minimal.environ.getAlloc(allocator, "OPENROUTER_WORKSPACE_ID") catch null;
    defer if (workspace_id) |value| allocator.free(value);

    var client = try openrouter.Client.init(allocator, init.io, .{ .api_key = api_key });
    defer client.deinit();

    var response = try client.files.list(.{ .limit = 10, .workspace_id = workspace_id }, .{});
    defer response.deinit();

    std.debug.print("Files: {d}\n", .{response.data.len});
    for (response.data) |file| {
        std.debug.print("- {s}: {s} ({d} bytes)\n", .{ file.id, file.filename, file.size_bytes });
    }
}
