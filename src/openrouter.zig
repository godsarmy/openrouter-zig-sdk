//! Root module for the OpenRouter Zig client.

const std = @import("std");

pub const Client = @import("client.zig").Client;
pub const Config = @import("client.zig").Config;

pub const version = "0.0.0";

test "openrouter module exposes package version" {
    try std.testing.expectEqualStrings("0.0.0", version);
}

test {
    _ = @import("client.zig");
    _ = @import("json.zig");
}
