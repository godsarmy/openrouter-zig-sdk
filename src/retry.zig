//! Retry policy configuration.

pub const RetryConfig = struct {
    max_attempts: u8 = 3,
    initial_delay_ms: u64 = 500,
    max_delay_ms: u64 = 60_000,
    multiplier: f64 = 1.5,
    retry_connection_errors: bool = true,
    retry_5xx: bool = true,
    retry_429: bool = true,
};
