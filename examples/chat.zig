const std = @import("std");
const openrouter = @import("openrouter");

pub fn main() !void {
    std.debug.print("chat example placeholder for openrouter-zig {s}\n", .{openrouter.version});
}
