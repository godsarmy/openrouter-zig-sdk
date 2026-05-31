//! Retry policy configuration.

const std = @import("std");

pub const RetryConfig = struct {
    max_attempts: u8 = 3,
    initial_delay_ms: u64 = 500,
    max_delay_ms: u64 = 60_000,
    multiplier: f64 = 1.5,
    retry_connection_errors: bool = true,
    retry_5xx: bool = true,
    retry_429: bool = true,
};

pub const RetryDecision = struct {
    retry: bool,
    delay_ms: u64 = 0,
};

pub fn shouldRetryStatus(config: RetryConfig, status: u16) bool {
    return switch (status) {
        429 => config.retry_429,
        500, 502, 503, 524, 529 => config.retry_5xx,
        else => false,
    };
}

pub fn shouldRetryConnectionError(config: RetryConfig) bool {
    return config.retry_connection_errors;
}

pub fn shouldAttempt(config: RetryConfig, attempt_index: u8) bool {
    return attempt_index + 1 < config.max_attempts;
}

pub fn decideStatusRetry(
    config: RetryConfig,
    attempt_index: u8,
    status: u16,
    retry_after: ?[]const u8,
) RetryDecision {
    if (!shouldAttempt(config, attempt_index)) return .{ .retry = false };
    if (!shouldRetryStatus(config, status)) return .{ .retry = false };

    return .{
        .retry = true,
        .delay_ms = delayMs(config, attempt_index, retry_after),
    };
}

pub fn decideConnectionErrorRetry(config: RetryConfig, attempt_index: u8) RetryDecision {
    if (!shouldAttempt(config, attempt_index)) return .{ .retry = false };
    if (!shouldRetryConnectionError(config)) return .{ .retry = false };

    return .{
        .retry = true,
        .delay_ms = delayMs(config, attempt_index, null),
    };
}

pub fn delayMs(config: RetryConfig, attempt_index: u8, retry_after: ?[]const u8) u64 {
    if (retry_after) |value| {
        if (parseRetryAfterMs(value)) |retry_after_ms| {
            return @min(retry_after_ms, config.max_delay_ms);
        }
    }

    return exponentialDelayMs(config, attempt_index);
}

pub fn exponentialDelayMs(config: RetryConfig, attempt_index: u8) u64 {
    if (config.initial_delay_ms == 0) return 0;

    var delay_float: f64 = @floatFromInt(config.initial_delay_ms);
    var remaining = attempt_index;
    while (remaining > 0) : (remaining -= 1) {
        delay_float *= config.multiplier;
        if (delay_float >= @as(f64, @floatFromInt(config.max_delay_ms))) return config.max_delay_ms;
    }

    const delay: u64 = @intFromFloat(@max(delay_float, 0));
    return @min(delay, config.max_delay_ms);
}

pub fn parseRetryAfterMs(value: []const u8) ?u64 {
    const trimmed = std.mem.trim(u8, value, " \t");
    if (trimmed.len == 0) return null;

    const seconds = std.fmt.parseUnsigned(u64, trimmed, 10) catch return null;
    return std.math.mul(u64, seconds, 1000) catch std.math.maxInt(u64);
}

test "status retry decision respects retryable statuses" {
    const config: RetryConfig = .{};

    try std.testing.expect(decideStatusRetry(config, 0, 500, null).retry);
    try std.testing.expect(decideStatusRetry(config, 0, 502, null).retry);
    try std.testing.expect(decideStatusRetry(config, 0, 503, null).retry);
    try std.testing.expect(decideStatusRetry(config, 0, 524, null).retry);
    try std.testing.expect(decideStatusRetry(config, 0, 529, null).retry);
    try std.testing.expect(decideStatusRetry(config, 0, 429, null).retry);
    try std.testing.expect(!decideStatusRetry(config, 0, 400, null).retry);
    try std.testing.expect(!decideStatusRetry(config, 0, 401, null).retry);
}

test "retry config toggles status categories" {
    try std.testing.expect(!decideStatusRetry(.{ .retry_429 = false }, 0, 429, null).retry);
    try std.testing.expect(!decideStatusRetry(.{ .retry_5xx = false }, 0, 500, null).retry);
}

test "connection error retry obeys config" {
    try std.testing.expect(decideConnectionErrorRetry(.{}, 0).retry);
    try std.testing.expect(!decideConnectionErrorRetry(.{ .retry_connection_errors = false }, 0).retry);
}

test "retry stops at configured max attempts" {
    const config: RetryConfig = .{ .max_attempts = 2 };

    try std.testing.expect(decideStatusRetry(config, 0, 500, null).retry);
    try std.testing.expect(!decideStatusRetry(config, 1, 500, null).retry);
}

test "exponential backoff is bounded" {
    const config: RetryConfig = .{
        .initial_delay_ms = 500,
        .max_delay_ms = 1_000,
        .multiplier = 2,
    };

    try std.testing.expectEqual(@as(u64, 500), exponentialDelayMs(config, 0));
    try std.testing.expectEqual(@as(u64, 1_000), exponentialDelayMs(config, 1));
    try std.testing.expectEqual(@as(u64, 1_000), exponentialDelayMs(config, 2));
}

test "retry-after header overrides exponential backoff and is bounded" {
    const config: RetryConfig = .{ .initial_delay_ms = 500, .max_delay_ms = 10_000 };

    try std.testing.expectEqual(@as(u64, 2_000), delayMs(config, 0, "2"));
    try std.testing.expectEqual(@as(u64, 10_000), delayMs(config, 0, "120"));
    try std.testing.expectEqual(@as(u64, 500), delayMs(config, 0, "not-a-number"));
}

test "parseRetryAfterMs handles whitespace and overflow" {
    try std.testing.expectEqual(@as(?u64, 3_000), parseRetryAfterMs(" 3 "));
    try std.testing.expectEqual(@as(?u64, null), parseRetryAfterMs(""));
    try std.testing.expectEqual(std.math.maxInt(u64), parseRetryAfterMs("18446744073709551615").?);
}
