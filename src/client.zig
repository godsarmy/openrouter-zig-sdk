//! Root client compile spike.

const std = @import("std");

pub const Config = struct {
    api_key: []const u8,
    base_url: []const u8 = "https://openrouter.ai/api/v1",
    timeout_ms: u64 = 60_000,
};

pub const Client = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    config: Config,
    http_client: std.http.Client,

    pub fn init(allocator: std.mem.Allocator, io: std.Io, config: Config) !Client {
        return .{
            .allocator = allocator,
            .io = io,
            .config = config,
            .http_client = .{
                .allocator = allocator,
                .io = io,
            },
        };
    }

    pub fn deinit(self: *Client) void {
        self.http_client.deinit();
        self.* = undefined;
    }
};

test "compile spike: caller-provided Io initializes std.http.Client" {
    var threaded: std.Io.Threaded = .init_single_threaded;
    defer threaded.deinit();

    var client = try Client.init(std.testing.allocator, threaded.io(), .{
        .api_key = "test-key",
    });
    defer client.deinit();

    try std.testing.expectEqualStrings("test-key", client.config.api_key);
}
