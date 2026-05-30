//! Root module for the OpenRouter Zig client.

const std = @import("std");

pub const version = "0.0.0";

test "openrouter module exposes package version" {
    try std.testing.expectEqualStrings("0.0.0", version);
}
