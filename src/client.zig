//! Root OpenRouter client.

const std = @import("std");
const config_mod = @import("config.zig");

pub const Config = config_mod.Config;

pub const Error = error{
    EmptyApiKey,
    InvalidBaseUrl,
};

pub const ChatResource = struct {
    completions: ChatCompletionsResource = .{},
};

pub const ChatCompletionsResource = struct {};
pub const ModelsResource = struct {};
pub const EmbeddingsResource = struct {};

/// Root OpenRouter client.
///
/// A `Client` owns its HTTP connection pool and is not thread-safe unless the
/// caller externally synchronizes access or uses one client per worker.
pub const Client = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    config: Config,
    base_uri: std.Uri,
    http_client: std.http.Client,
    chat: ChatResource,
    models: ModelsResource,
    embeddings: EmbeddingsResource,

    pub fn init(allocator: std.mem.Allocator, io: std.Io, config: Config) Error!Client {
        if (config.api_key.len == 0) return error.EmptyApiKey;

        const base_uri = validateBaseUrl(config.base_url) catch return error.InvalidBaseUrl;

        return .{
            .allocator = allocator,
            .io = io,
            .config = config,
            .base_uri = base_uri,
            .http_client = .{
                .allocator = allocator,
                .io = io,
            },
            .chat = .{},
            .models = .{},
            .embeddings = .{},
        };
    }

    pub fn deinit(self: *Client) void {
        self.http_client.deinit();
        self.* = undefined;
    }
};

fn validateBaseUrl(base_url: []const u8) !std.Uri {
    const uri = try std.Uri.parse(base_url);
    if (!std.mem.eql(u8, uri.scheme, "http") and !std.mem.eql(u8, uri.scheme, "https")) {
        return error.InvalidBaseUrl;
    }
    if (uri.host == null) return error.InvalidBaseUrl;
    if (uri.fragment != null) return error.InvalidBaseUrl;
    return uri;
}

test "client initializes with API key and caller-provided Io" {
    var threaded: std.Io.Threaded = .init_single_threaded;
    defer threaded.deinit();

    var client = try Client.init(std.testing.allocator, threaded.io(), .{
        .api_key = "test-key",
    });
    defer client.deinit();

    try std.testing.expectEqualStrings("test-key", client.config.api_key);
    try std.testing.expectEqualStrings("https", client.base_uri.scheme);
}

test "client supports custom base URL" {
    var threaded: std.Io.Threaded = .init_single_threaded;
    defer threaded.deinit();

    var client = try Client.init(std.testing.allocator, threaded.io(), .{
        .api_key = "test-key",
        .base_url = "http://localhost:8080/api/v1",
    });
    defer client.deinit();

    try std.testing.expectEqualStrings("http", client.base_uri.scheme);
    try std.testing.expect(client.base_uri.host != null);
}

test "client stores optional attribution headers" {
    var threaded: std.Io.Threaded = .init_single_threaded;
    defer threaded.deinit();

    var client = try Client.init(std.testing.allocator, threaded.io(), .{
        .api_key = "test-key",
        .http_referer = "https://example.com",
        .x_title = "openrouter-zig-test",
    });
    defer client.deinit();

    try std.testing.expectEqualStrings("https://example.com", client.config.http_referer.?);
    try std.testing.expectEqualStrings("openrouter-zig-test", client.config.x_title.?);
}

test "client rejects invalid base URL" {
    var threaded: std.Io.Threaded = .init_single_threaded;
    defer threaded.deinit();

    try std.testing.expectError(error.InvalidBaseUrl, Client.init(std.testing.allocator, threaded.io(), .{
        .api_key = "test-key",
        .base_url = "not a url",
    }));
    try std.testing.expectError(error.InvalidBaseUrl, Client.init(std.testing.allocator, threaded.io(), .{
        .api_key = "test-key",
        .base_url = "ftp://example.com",
    }));
}

test "client rejects empty API key" {
    var threaded: std.Io.Threaded = .init_single_threaded;
    defer threaded.deinit();

    try std.testing.expectError(error.EmptyApiKey, Client.init(std.testing.allocator, threaded.io(), .{
        .api_key = "",
    }));
}

test "client initializes resource namespaces" {
    var threaded: std.Io.Threaded = .init_single_threaded;
    defer threaded.deinit();

    var client = try Client.init(std.testing.allocator, threaded.io(), .{
        .api_key = "test-key",
    });
    defer client.deinit();

    _ = client.chat;
    _ = client.chat.completions;
    _ = client.models;
    _ = client.embeddings;
}
