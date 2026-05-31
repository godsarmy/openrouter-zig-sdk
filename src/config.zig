//! Shared client configuration.

const retry = @import("retry.zig");

pub const Config = struct {
    api_key: []const u8,
    base_url: []const u8 = "https://openrouter.ai/api/v1",
    http_referer: ?[]const u8 = null,
    x_title: ?[]const u8 = null,
    timeout_ms: u64 = 60_000,
    retry: retry.RetryConfig = .{},
};
