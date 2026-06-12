const std = @import("std");
const openrouter = @import("openrouter");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const api_key = init.minimal.environ.getAlloc(allocator, "OPENROUTER_MANAGEMENT_API_KEY") catch return error.MissingApiKey;
    defer allocator.free(api_key);

    var client = try openrouter.Client.init(allocator, init.io, .{ .api_key = api_key });
    defer client.deinit();

    var response = try client.organization.members.list(.{ .limit = 10 }, .{});
    defer response.deinit();

    std.debug.print("Organization members: {d}", .{response.data.len});
    if (response.total_count) |total_count| std.debug.print(" of {d}", .{total_count});
    std.debug.print("\n", .{});

    for (response.data) |member| {
        std.debug.print("- {s}: {s}\n", .{ member.id orelse "<unknown>", member.role orelse "<unknown>" });
    }
}
