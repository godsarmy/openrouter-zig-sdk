//! Root module for the OpenRouter Zig client.

const std = @import("std");

pub const Client = @import("client.zig").Client;
pub const Config = @import("config.zig").Config;
pub const ActivityGetRequest = @import("activity.zig").GetRequest;
pub const ActivityGetResponse = @import("activity.zig").GetResponse;
pub const ActivityItem = @import("activity.zig").ActivityItem;
pub const ApiError = @import("errors.zig").ApiError;
pub const ChatCompletionResponse = @import("chat.zig").CompletionResponse;
pub const ChatCompletionChunk = @import("stream.zig").CompletionChunk;
pub const ChatCompletionStream = @import("stream.zig").CompletionStream;
pub const ChatMessage = @import("chat.zig").Message;
pub const ChatMessageContent = @import("chat.zig").MessageContent;
pub const ChatRole = @import("chat.zig").Role;
pub const Credits = @import("credits.zig").Credits;
pub const CreditsGetResponse = @import("credits.zig").GetResponse;
pub const RankingDailyItem = @import("datasets.zig").RankingDailyItem;
pub const RankingDailyMeta = @import("datasets.zig").RankingDailyMeta;
pub const RankingsDailyItem = @import("datasets.zig").RankingDailyItem;
pub const RankingsDailyMeta = @import("datasets.zig").RankingDailyMeta;
pub const RankingsDailyGetRequest = @import("datasets.zig").RankingsDailyGetRequest;
pub const RankingsDailyGetResponse = @import("datasets.zig").RankingsDailyGetResponse;
pub const Embedding = @import("embeddings.zig").Embedding;
pub const EmbeddingInput = @import("embeddings.zig").Input;
pub const EmbeddingsCreateRequest = @import("embeddings.zig").CreateRequest;
pub const EmbeddingsCreateResponse = @import("embeddings.zig").CreateResponse;
pub const Header = @import("options.zig").Header;
pub const Generation = @import("generation.zig").Generation;
pub const GenerationContent = @import("generation.zig").GenerationContent;
pub const GenerationContentInput = @import("generation.zig").ContentInput;
pub const GenerationContentOutput = @import("generation.zig").ContentOutput;
pub const GenerationContentRequest = @import("generation.zig").ContentRequest;
pub const GenerationContentResponse = @import("generation.zig").ContentResponse;
pub const GenerationGetRequest = @import("generation.zig").GetRequest;
pub const GenerationGetResponse = @import("generation.zig").GetResponse;
pub const GenerationProviderResponse = @import("generation.zig").ProviderResponse;
pub const HttpRequest = @import("http.zig").HttpRequest;
pub const HttpResponse = @import("http.zig").HttpResponse;
pub const Model = @import("models.zig").Model;
pub const ModelsListResponse = @import("models.zig").ListResponse;
pub const OffsetLimit = @import("pagination.zig").OffsetLimit;
pub const Pager = @import("pagination.zig").Pager;
pub const Provider = @import("providers.zig").Provider;
pub const ProvidersListResponse = @import("providers.zig").ListResponse;
pub const RequestOptions = @import("options.zig").RequestOptions;
pub const RetryConfig = @import("retry.zig").RetryConfig;
pub const json = @import("json.zig");
pub const pagination = @import("pagination.zig");
pub const stream = @import("stream.zig");

pub const version = "0.2.0-dev";

test "openrouter module exposes package version" {
    try std.testing.expectEqualStrings("0.2.0-dev", version);
}

test {
    _ = @import("activity.zig");
    _ = @import("chat.zig");
    _ = @import("client.zig");
    _ = @import("credits.zig");
    _ = @import("datasets.zig");
    _ = @import("embeddings.zig");
    _ = @import("errors.zig");
    _ = @import("generation.zig");
    _ = @import("http.zig");
    _ = @import("json.zig");
    _ = @import("models.zig");
    _ = @import("options.zig");
    _ = @import("pagination.zig");
    _ = @import("providers.zig");
    _ = @import("stream.zig");
}
