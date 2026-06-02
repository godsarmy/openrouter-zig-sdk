//! Root module for the OpenRouter Zig client.

const std = @import("std");

pub const Client = @import("client.zig").Client;
pub const Config = @import("config.zig").Config;
pub const ApiError = @import("errors.zig").ApiError;
pub const ChatCompletionResponse = @import("chat.zig").CompletionResponse;
pub const ChatCompletionChunk = @import("stream.zig").CompletionChunk;
pub const ChatCompletionStream = @import("stream.zig").CompletionStream;
pub const ChatMessage = @import("chat.zig").Message;
pub const ChatMessageContent = @import("chat.zig").MessageContent;
pub const ChatRole = @import("chat.zig").Role;
pub const Embedding = @import("embeddings.zig").Embedding;
pub const EmbeddingInput = @import("embeddings.zig").Input;
pub const EmbeddingsCreateRequest = @import("embeddings.zig").CreateRequest;
pub const EmbeddingsCreateResponse = @import("embeddings.zig").CreateResponse;
pub const Header = @import("options.zig").Header;
pub const HttpRequest = @import("http.zig").HttpRequest;
pub const HttpResponse = @import("http.zig").HttpResponse;
pub const Model = @import("models.zig").Model;
pub const ModelsListResponse = @import("models.zig").ListResponse;
pub const RequestOptions = @import("options.zig").RequestOptions;
pub const RetryConfig = @import("retry.zig").RetryConfig;
pub const json = @import("json.zig");
pub const stream = @import("stream.zig");

pub const version = "0.0.0";

test "openrouter module exposes package version" {
    try std.testing.expectEqualStrings("0.0.0", version);
}

test {
    _ = @import("chat.zig");
    _ = @import("client.zig");
    _ = @import("embeddings.zig");
    _ = @import("errors.zig");
    _ = @import("http.zig");
    _ = @import("json.zig");
    _ = @import("models.zig");
    _ = @import("options.zig");
    _ = @import("stream.zig");
}
