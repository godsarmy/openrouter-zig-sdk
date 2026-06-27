const std = @import("std");
const openrouter = @import("openrouter");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const api_key = init.minimal.environ.getAlloc(allocator, "OPENROUTER_MANAGEMENT_API_KEY") catch return error.MissingApiKey;
    defer allocator.free(api_key);

    var client = try openrouter.Client.init(allocator, init.io, .{ .api_key = api_key });
    defer client.deinit();

    var response = try client.workspaces.list(.{ .limit = 10 }, .{});
    defer response.deinit();

    std.debug.print("Workspaces: {d}", .{response.data.len});
    if (response.total_count) |total_count| std.debug.print(" of {d}", .{total_count});
    std.debug.print("\n", .{});

    for (response.data) |item| {
        std.debug.print("- {s}: {s}\n", .{ item.id orelse "<unknown>", item.name orelse "<unnamed>" });
    }

    const workspace_id = init.minimal.environ.getAlloc(allocator, "OPENROUTER_WORKSPACE_ID") catch return;
    defer allocator.free(workspace_id);
    var budgets = try client.workspaces.budgets.list(workspace_id, .{});
    defer budgets.deinit();

    std.debug.print("Budgets for {s}: {d}\n", .{ workspace_id, budgets.data.len });
    for (budgets.data) |budget| {
        std.debug.print("- {s}: ${d} reset={s}\n", .{
            budget.id,
            budget.limit_usd,
            budget.reset_interval orelse "lifetime",
        });
    }
}
