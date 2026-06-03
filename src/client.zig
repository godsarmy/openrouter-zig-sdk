//! Root OpenRouter client.

const std = @import("std");
const chat_mod = @import("chat.zig");
const config_mod = @import("config.zig");
const credits_mod = @import("credits.zig");
const embeddings_mod = @import("embeddings.zig");
const models_mod = @import("models.zig");
const options_mod = @import("options.zig");
const providers_mod = @import("providers.zig");
const stream_mod = @import("stream.zig");

pub const Config = config_mod.Config;

pub const Error = error{
    EmptyApiKey,
    InvalidBaseUrl,
};

pub const ChatResource = struct {
    completions: ChatCompletionsResource = .{},
};

pub const ChatCompletionsResource = struct {
    pub fn create(
        self: *ChatCompletionsResource,
        request: chat_mod.CompletionRequest,
        request_options: options_mod.RequestOptions,
    ) !chat_mod.CompletionResponse {
        const chat: *ChatResource = @alignCast(@fieldParentPtr("completions", self));
        const client: *Client = @alignCast(@fieldParentPtr("chat", chat));
        return chat_mod.create(client, request, request_options);
    }

    pub fn stream(
        self: *ChatCompletionsResource,
        request: chat_mod.CompletionRequest,
        request_options: options_mod.RequestOptions,
    ) !stream_mod.CompletionStream {
        const chat: *ChatResource = @alignCast(@fieldParentPtr("completions", self));
        const client: *Client = @alignCast(@fieldParentPtr("chat", chat));
        return stream_mod.stream(client, request, request_options);
    }
};
pub const ModelsResource = struct {
    pub fn list(self: *ModelsResource, request_options: options_mod.RequestOptions) !models_mod.ListResponse {
        const client: *Client = @alignCast(@fieldParentPtr("models", self));
        return models_mod.list(client, request_options);
    }
};
pub const EmbeddingsResource = struct {
    pub fn create(
        self: *EmbeddingsResource,
        request: embeddings_mod.CreateRequest,
        request_options: options_mod.RequestOptions,
    ) !embeddings_mod.CreateResponse {
        const client: *Client = @alignCast(@fieldParentPtr("embeddings", self));
        return embeddings_mod.create(client, request, request_options);
    }
};
pub const CreditsResource = struct {
    pub fn get(self: *CreditsResource, request_options: options_mod.RequestOptions) !credits_mod.GetResponse {
        const client: *Client = @alignCast(@fieldParentPtr("credits", self));
        return credits_mod.get(client, request_options);
    }
};
pub const ProvidersResource = struct {
    pub fn list(self: *ProvidersResource, request_options: options_mod.RequestOptions) !providers_mod.ListResponse {
        const client: *Client = @alignCast(@fieldParentPtr("providers", self));
        return providers_mod.list(client, request_options);
    }
};

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
    credits: CreditsResource,
    providers: ProvidersResource,

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
            .credits = .{},
            .providers = .{},
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
    _ = client.credits;
    _ = client.providers;
}
