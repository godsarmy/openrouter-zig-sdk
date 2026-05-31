//! Per-request options and option merging.

const std = @import("std");

const config_mod = @import("config.zig");
const retry_mod = @import("retry.zig");

pub const Error = error{
    EmptyHeaderName,
    ReservedHeader,
};

pub const Header = struct {
    name: []const u8,
    value: []const u8,
};

pub const RequestOptions = struct {
    timeout_ms: ?u64 = null,
    retry: ?retry_mod.RetryConfig = null,
    extra_headers: []const Header = &.{},
};

pub const EffectiveOptions = struct {
    timeout_ms: u64,
    retry: retry_mod.RetryConfig,
    extra_headers: []const Header,
};

pub fn merge(config: config_mod.Config, options: RequestOptions) Error!EffectiveOptions {
    try validateExtraHeaders(options.extra_headers);

    return .{
        .timeout_ms = options.timeout_ms orelse config.timeout_ms,
        .retry = options.retry orelse config.retry,
        .extra_headers = options.extra_headers,
    };
}

pub fn validateExtraHeaders(headers: []const Header) Error!void {
    for (headers) |header| {
        if (header.name.len == 0) return error.EmptyHeaderName;
        if (isReservedHeader(header.name)) return error.ReservedHeader;
    }
}

pub fn isReservedHeader(name: []const u8) bool {
    return std.ascii.eqlIgnoreCase(name, "authorization") or
        std.ascii.eqlIgnoreCase(name, "content-type") or
        std.ascii.eqlIgnoreCase(name, "accept") or
        std.ascii.eqlIgnoreCase(name, "user-agent") or
        std.ascii.eqlIgnoreCase(name, "http-referer") or
        std.ascii.eqlIgnoreCase(name, "x-title");
}

test "default request options use client defaults" {
    const config: config_mod.Config = .{ .api_key = "test-key" };
    const effective = try merge(config, .{});

    try std.testing.expectEqual(@as(u64, 60_000), effective.timeout_ms);
    try std.testing.expectEqual(@as(u8, 3), effective.retry.max_attempts);
    try std.testing.expectEqual(@as(usize, 0), effective.extra_headers.len);
}

test "request options override timeout and retry" {
    const config: config_mod.Config = .{ .api_key = "test-key" };
    const effective = try merge(config, .{
        .timeout_ms = 1_000,
        .retry = .{ .max_attempts = 1 },
    });

    try std.testing.expectEqual(@as(u64, 1_000), effective.timeout_ms);
    try std.testing.expectEqual(@as(u8, 1), effective.retry.max_attempts);
}

test "request options accept non-reserved extra headers" {
    const headers = &.{Header{ .name = "X-Custom", .value = "value" }};
    const effective = try merge(.{ .api_key = "test-key" }, .{ .extra_headers = headers });

    try std.testing.expectEqual(@as(usize, 1), effective.extra_headers.len);
    try std.testing.expectEqualStrings("X-Custom", effective.extra_headers[0].name);
}

test "request options reject empty header names" {
    try std.testing.expectError(error.EmptyHeaderName, validateExtraHeaders(&.{
        .{ .name = "", .value = "value" },
    }));
}

test "request options reject reserved headers case-insensitively" {
    const reserved = [_][]const u8{
        "Authorization",
        "content-type",
        "ACCEPT",
        "User-Agent",
        "HTTP-Referer",
        "x-title",
    };

    for (reserved) |name| {
        try std.testing.expectError(error.ReservedHeader, validateExtraHeaders(&.{
            .{ .name = name, .value = "value" },
        }));
    }
}
