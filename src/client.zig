//! Root OpenRouter client.

const std = @import("std");
const decisions_mod = @import("decisions.zig");
const oauth_mod = @import("oauth.zig");
const interns_mod = @import("interns.zig");
const containers_mod = @import("containers.zig");
const vault_mod = @import("vault.zig");
const activity_mod = @import("activity.zig");
const analytics_mod = @import("analytics.zig");
const audio_mod = @import("audio.zig");
const byok_mod = @import("byok.zig");
const benchmarks_mod = @import("benchmarks.zig");
const chat_mod = @import("chat.zig");
const classifications_mod = @import("classifications.zig");
const config_mod = @import("config.zig");
const credits_mod = @import("credits.zig");
const auth_keys_mod = @import("auth_keys.zig");
const datasets_mod = @import("datasets.zig");
const end_users_mod = @import("end_users.zig");
const embeddings_mod = @import("embeddings.zig");
const batches_mod = @import("batches.zig");
const endpoints_mod = @import("endpoints.zig");
const files_mod = @import("files.zig");
const generation_mod = @import("generation.zig");
const guardrails_mod = @import("guardrails.zig");
const images_mod = @import("images.zig");
const key_mod = @import("key.zig");
const keys_mod = @import("keys.zig");
const messages_mod = @import("messages.zig");
const models_mod = @import("models.zig");
const observability_mod = @import("observability.zig");
const options_mod = @import("options.zig");
const organization_mod = @import("organization.zig");
const presets_mod = @import("presets.zig");
const scim_mod = @import("scim.zig");
const private_endpoints_mod = @import("private_endpoints.zig");
const providers_mod = @import("providers.zig");
const rerank_mod = @import("rerank.zig");
const responses_mod = @import("responses.zig");
const stream_mod = @import("stream.zig");
const tools_mod = @import("tools.zig");
const videos_mod = @import("videos.zig");
const workspaces_mod = @import("workspaces.zig");

pub const Config = config_mod.Config;

pub const Error = error{
    EmptyApiKey,
    InvalidBaseUrl,
};

pub const ChatResource = struct {
    completions: ChatCompletionsResource = .{},
};
pub const ToolsResource = struct {
    pub fn list(self: *ToolsResource, request: tools_mod.ListRequest, request_options: options_mod.RequestOptions) !tools_mod.ListResponse {
        const client: *Client = @alignCast(@fieldParentPtr("tools", self));
        return tools_mod.list(client, request, request_options);
    }

    pub fn get(self: *ToolsResource, request: tools_mod.GetRequest, request_options: options_mod.RequestOptions) !tools_mod.GetResponse {
        const client: *Client = @alignCast(@fieldParentPtr("tools", self));
        return tools_mod.get(client, request, request_options);
    }
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
pub const AudioResource = struct {
    speech: AudioSpeechResource = .{},
    transcriptions: AudioTranscriptionsResource = .{},
};
pub const AudioSpeechResource = struct {
    pub fn create(self: *AudioSpeechResource, request: audio_mod.SpeechCreateRequest, request_options: options_mod.RequestOptions) !audio_mod.SpeechCreateResponse {
        const audio: *AudioResource = @alignCast(@fieldParentPtr("speech", self));
        const client: *Client = @alignCast(@fieldParentPtr("audio", audio));
        return audio_mod.createSpeech(client, request, request_options);
    }
};
pub const AudioTranscriptionsResource = struct {
    pub fn create(self: *AudioTranscriptionsResource, request: audio_mod.TranscriptionsCreateRequest, request_options: options_mod.RequestOptions) !audio_mod.TranscriptionsCreateResponse {
        const audio: *AudioResource = @alignCast(@fieldParentPtr("transcriptions", self));
        const client: *Client = @alignCast(@fieldParentPtr("audio", audio));
        return audio_mod.createTranscription(client, request, request_options);
    }
};
pub const ModelsResource = struct {
    user: ModelsUserResource = .{},
    endpoints: ModelsEndpointsResource = .{},

    pub fn list(self: *ModelsResource, request_options: options_mod.RequestOptions) !models_mod.ListResponse {
        const client: *Client = @alignCast(@fieldParentPtr("models", self));
        return models_mod.list(client, request_options);
    }

    pub fn count(
        self: *ModelsResource,
        request: models_mod.CountRequest,
        request_options: options_mod.RequestOptions,
    ) !models_mod.CountResponse {
        const client: *Client = @alignCast(@fieldParentPtr("models", self));
        return models_mod.count(client, request, request_options);
    }

    pub fn get(
        self: *ModelsResource,
        request: models_mod.GetRequest,
        request_options: options_mod.RequestOptions,
    ) !models_mod.GetResponse {
        const client: *Client = @alignCast(@fieldParentPtr("models", self));
        return models_mod.get(client, request, request_options);
    }
};
pub const ModelsEndpointsResource = struct {
    pub fn list(
        self: *ModelsEndpointsResource,
        request: models_mod.EndpointsListRequest,
        request_options: options_mod.RequestOptions,
    ) !models_mod.EndpointsListResponse {
        const models: *ModelsResource = @alignCast(@fieldParentPtr("endpoints", self));
        const client: *Client = @alignCast(@fieldParentPtr("models", models));
        return models_mod.listEndpoints(client, request, request_options);
    }
};
pub const ModelsUserResource = struct {
    pub fn list(self: *ModelsUserResource, request_options: options_mod.RequestOptions) !models_mod.UserListResponse {
        const models: *ModelsResource = @alignCast(@fieldParentPtr("user", self));
        const client: *Client = @alignCast(@fieldParentPtr("models", models));
        return models_mod.listUser(client, request_options);
    }
};
pub const EmbeddingsResource = struct {
    models: EmbeddingsModelsResource = .{},

    pub fn create(
        self: *EmbeddingsResource,
        request: embeddings_mod.CreateRequest,
        request_options: options_mod.RequestOptions,
    ) !embeddings_mod.CreateResponse {
        const client: *Client = @alignCast(@fieldParentPtr("embeddings", self));
        return embeddings_mod.create(client, request, request_options);
    }
};
pub const EmbeddingsModelsResource = struct {
    pub fn list(self: *EmbeddingsModelsResource, request_options: options_mod.RequestOptions) !embeddings_mod.ModelsListResponse {
        const embeddings: *EmbeddingsResource = @alignCast(@fieldParentPtr("models", self));
        const client: *Client = @alignCast(@fieldParentPtr("embeddings", embeddings));
        return embeddings_mod.listModels(client, request_options);
    }
};
pub const EndUsersResource = struct {
    pub fn list(self: *EndUsersResource, request: end_users_mod.ListRequest, request_options: options_mod.RequestOptions) !end_users_mod.ListResponse {
        const client: *Client = @alignCast(@fieldParentPtr("end_users", self));
        return end_users_mod.list(client, request, request_options);
    }
    pub fn create(self: *EndUsersResource, request: end_users_mod.CreateRequest, request_options: options_mod.RequestOptions) !end_users_mod.CreateResponse {
        const client: *Client = @alignCast(@fieldParentPtr("end_users", self));
        return end_users_mod.create(client, request, request_options);
    }
    pub fn get(self: *EndUsersResource, user: []const u8, request_options: options_mod.RequestOptions) !end_users_mod.GetResponse {
        const client: *Client = @alignCast(@fieldParentPtr("end_users", self));
        return end_users_mod.get(client, user, request_options);
    }
    pub fn update(self: *EndUsersResource, user: []const u8, request: end_users_mod.UpdateRequest, request_options: options_mod.RequestOptions) !end_users_mod.UpdateResponse {
        const client: *Client = @alignCast(@fieldParentPtr("end_users", self));
        return end_users_mod.update(client, user, request, request_options);
    }
    pub fn delete(self: *EndUsersResource, user: []const u8, request_options: options_mod.RequestOptions) !end_users_mod.DeleteResponse {
        const client: *Client = @alignCast(@fieldParentPtr("end_users", self));
        return end_users_mod.delete(client, user, request_options);
    }
};
pub const BatchesResource = struct {
    pub fn list(self: *BatchesResource, request: batches_mod.ListRequest, request_options: options_mod.RequestOptions) !batches_mod.ListResponse {
        const client: *Client = @alignCast(@fieldParentPtr("batches", self));
        return batches_mod.list(client, request, request_options);
    }
    pub fn create(self: *BatchesResource, request: batches_mod.CreateRequest, request_options: options_mod.RequestOptions) !batches_mod.BatchResponse {
        const client: *Client = @alignCast(@fieldParentPtr("batches", self));
        return batches_mod.create(client, request, request_options);
    }
    pub fn get(self: *BatchesResource, id: []const u8, request_options: options_mod.RequestOptions) !batches_mod.BatchResponse {
        const client: *Client = @alignCast(@fieldParentPtr("batches", self));
        return batches_mod.get(client, id, request_options);
    }
    pub fn delete(self: *BatchesResource, id: []const u8, request_options: options_mod.RequestOptions) !batches_mod.DeleteResponse {
        const client: *Client = @alignCast(@fieldParentPtr("batches", self));
        return batches_mod.delete(client, id, request_options);
    }
};
pub const ImagesResource = struct {
    models: ImagesModelsResource = .{},
    pub fn create(self: *ImagesResource, request: images_mod.CreateRequest, request_options: options_mod.RequestOptions) !images_mod.CreateResponse {
        const client: *Client = @alignCast(@fieldParentPtr("images", self));
        return images_mod.create(client, request, request_options);
    }
};
pub const ImagesModelsResource = struct {
    endpoints: ImagesModelsEndpointsResource = .{},
    pub fn list(self: *ImagesModelsResource, request_options: options_mod.RequestOptions) !images_mod.ModelsListResponse {
        const images: *ImagesResource = @alignCast(@fieldParentPtr("models", self));
        const client: *Client = @alignCast(@fieldParentPtr("images", images));
        return images_mod.listModels(client, request_options);
    }
};
pub const ImagesModelsEndpointsResource = struct {
    pub fn list(self: *ImagesModelsEndpointsResource, request: images_mod.ListModelEndpointsRequest, request_options: options_mod.RequestOptions) !images_mod.ModelEndpointsResponse {
        const models: *ImagesModelsResource = @alignCast(@fieldParentPtr("endpoints", self));
        const images: *ImagesResource = @alignCast(@fieldParentPtr("models", models));
        const client: *Client = @alignCast(@fieldParentPtr("images", images));
        return images_mod.listModelEndpoints(client, request, request_options);
    }
};
pub const EndpointsResource = struct {
    zdr: EndpointsZdrResource = .{},
};
pub const EndpointsZdrResource = struct {
    pub fn list(self: *EndpointsZdrResource, request_options: options_mod.RequestOptions) !endpoints_mod.ZdrListResponse {
        const endpoints: *EndpointsResource = @alignCast(@fieldParentPtr("zdr", self));
        const client: *Client = @alignCast(@fieldParentPtr("endpoints", endpoints));
        return endpoints_mod.listZdr(client, request_options);
    }
};
pub const VideosResource = struct {
    models: VideosModelsResource = .{},

    pub fn create(self: *VideosResource, request: videos_mod.CreateRequest, request_options: options_mod.RequestOptions) !videos_mod.JobResponse {
        const client: *Client = @alignCast(@fieldParentPtr("videos", self));
        return videos_mod.create(client, request, request_options);
    }

    pub fn get(self: *VideosResource, request: videos_mod.GetRequest, request_options: options_mod.RequestOptions) !videos_mod.JobResponse {
        const client: *Client = @alignCast(@fieldParentPtr("videos", self));
        return videos_mod.get(client, request, request_options);
    }

    pub fn content(self: *VideosResource, request: videos_mod.ContentRequest, request_options: options_mod.RequestOptions) !videos_mod.ContentResponse {
        const client: *Client = @alignCast(@fieldParentPtr("videos", self));
        return videos_mod.content(client, request, request_options);
    }
};
pub const VideosModelsResource = struct {
    pub fn list(self: *VideosModelsResource, request_options: options_mod.RequestOptions) !videos_mod.ModelsListResponse {
        const videos: *VideosResource = @alignCast(@fieldParentPtr("models", self));
        const client: *Client = @alignCast(@fieldParentPtr("videos", videos));
        return videos_mod.listModels(client, request_options);
    }
};
pub const FilesResource = struct {
    pub fn list(self: *FilesResource, request: files_mod.ListRequest, request_options: options_mod.RequestOptions) !files_mod.ListResponse {
        const client: *Client = @alignCast(@fieldParentPtr("files", self));
        return files_mod.list(client, request, request_options);
    }
    pub fn upload(self: *FilesResource, request: files_mod.UploadRequest, request_options: options_mod.RequestOptions) !files_mod.MetadataResponse {
        const client: *Client = @alignCast(@fieldParentPtr("files", self));
        return files_mod.upload(client, request, request_options);
    }
    pub fn get(self: *FilesResource, file_id: []const u8, request: files_mod.WorkspaceRequest, request_options: options_mod.RequestOptions) !files_mod.MetadataResponse {
        const client: *Client = @alignCast(@fieldParentPtr("files", self));
        return files_mod.get(client, file_id, request, request_options);
    }
    pub fn delete(self: *FilesResource, file_id: []const u8, request: files_mod.WorkspaceRequest, request_options: options_mod.RequestOptions) !files_mod.DeleteResponse {
        const client: *Client = @alignCast(@fieldParentPtr("files", self));
        return files_mod.delete(client, file_id, request, request_options);
    }
    pub fn content(self: *FilesResource, file_id: []const u8, request: files_mod.WorkspaceRequest, request_options: options_mod.RequestOptions) !files_mod.ContentResponse {
        const client: *Client = @alignCast(@fieldParentPtr("files", self));
        return files_mod.content(client, file_id, request, request_options);
    }
};
pub const PresetsResource = struct {
    chat: PresetsChatResource = .{},
    messages: PresetsMessagesResource = .{},
    responses: PresetsResponsesResource = .{},
    versions: PresetsVersionsResource = .{},

    pub fn list(self: *PresetsResource, request: presets_mod.ListRequest, request_options: options_mod.RequestOptions) !presets_mod.ListResponse {
        const client: *Client = @alignCast(@fieldParentPtr("presets", self));
        return presets_mod.list(client, request, request_options);
    }

    pub fn get(self: *PresetsResource, request: presets_mod.GetRequest, request_options: options_mod.RequestOptions) !presets_mod.GetResponse {
        const client: *Client = @alignCast(@fieldParentPtr("presets", self));
        return presets_mod.get(client, request, request_options);
    }
};
pub const PresetsChatResource = struct {
    completions: PresetsChatCompletionsResource = .{},
};
pub const PresetsChatCompletionsResource = struct {
    pub fn create(
        self: *PresetsChatCompletionsResource,
        request: presets_mod.ChatCompletionsCreateRequest,
        request_options: options_mod.RequestOptions,
    ) !presets_mod.ChatCompletionsCreateResponse {
        const chat: *PresetsChatResource = @alignCast(@fieldParentPtr("completions", self));
        const presets: *PresetsResource = @alignCast(@fieldParentPtr("chat", chat));
        const client: *Client = @alignCast(@fieldParentPtr("presets", presets));
        return presets_mod.createChatCompletion(client, request, request_options);
    }
};
pub const PresetsMessagesResource = struct {
    pub fn create(
        self: *PresetsMessagesResource,
        request: presets_mod.MessagesCreateRequest,
        request_options: options_mod.RequestOptions,
    ) !presets_mod.MessagesCreateResponse {
        const presets: *PresetsResource = @alignCast(@fieldParentPtr("messages", self));
        const client: *Client = @alignCast(@fieldParentPtr("presets", presets));
        return presets_mod.createMessage(client, request, request_options);
    }
};
pub const PresetsResponsesResource = struct {
    pub fn create(
        self: *PresetsResponsesResource,
        request: presets_mod.ResponsesCreateRequest,
        request_options: options_mod.RequestOptions,
    ) !presets_mod.ResponsesCreateResponse {
        const presets: *PresetsResource = @alignCast(@fieldParentPtr("responses", self));
        const client: *Client = @alignCast(@fieldParentPtr("presets", presets));
        return presets_mod.createResponse(client, request, request_options);
    }
};
pub const PresetsVersionsResource = struct {
    pub fn list(
        self: *PresetsVersionsResource,
        request: presets_mod.VersionsListRequest,
        request_options: options_mod.RequestOptions,
    ) !presets_mod.VersionsListResponse {
        const presets: *PresetsResource = @alignCast(@fieldParentPtr("versions", self));
        const client: *Client = @alignCast(@fieldParentPtr("presets", presets));
        return presets_mod.listVersions(client, request, request_options);
    }

    pub fn get(
        self: *PresetsVersionsResource,
        request: presets_mod.VersionGetRequest,
        request_options: options_mod.RequestOptions,
    ) !presets_mod.VersionGetResponse {
        const presets: *PresetsResource = @alignCast(@fieldParentPtr("versions", self));
        const client: *Client = @alignCast(@fieldParentPtr("presets", presets));
        return presets_mod.getVersion(client, request, request_options);
    }
};
pub const RerankResource = struct {
    pub fn create(self: *RerankResource, request: rerank_mod.CreateRequest, request_options: options_mod.RequestOptions) !rerank_mod.CreateResponse {
        const client: *Client = @alignCast(@fieldParentPtr("rerank", self));
        return rerank_mod.create(client, request, request_options);
    }
};
pub const ResponsesResource = struct {
    pub fn create(self: *ResponsesResource, request: responses_mod.CreateRequest, request_options: options_mod.RequestOptions) !responses_mod.CreateResponse {
        const client: *Client = @alignCast(@fieldParentPtr("responses", self));
        return responses_mod.create(client, request, request_options);
    }

    pub fn stream(self: *ResponsesResource, request: responses_mod.CreateRequest, request_options: options_mod.RequestOptions) !responses_mod.ResponsesStream {
        const client: *Client = @alignCast(@fieldParentPtr("responses", self));
        return responses_mod.stream(client, request, request_options);
    }
};
pub const MessagesResource = struct {
    pub fn create(self: *MessagesResource, request: messages_mod.CreateRequest, request_options: options_mod.RequestOptions) !messages_mod.CreateResponse {
        const client: *Client = @alignCast(@fieldParentPtr("messages", self));
        return messages_mod.create(client, request, request_options);
    }

    pub fn stream(self: *MessagesResource, request: messages_mod.CreateRequest, request_options: options_mod.RequestOptions) !messages_mod.MessageStream {
        const client: *Client = @alignCast(@fieldParentPtr("messages", self));
        return messages_mod.stream(client, request, request_options);
    }
};
pub const CreditsResource = struct {
    pub fn get(self: *CreditsResource, request_options: options_mod.RequestOptions) !credits_mod.GetResponse {
        const client: *Client = @alignCast(@fieldParentPtr("credits", self));
        return credits_mod.get(client, request_options);
    }
};
pub const ByokResource = struct {
    pub fn list(self: *ByokResource, request: byok_mod.ListRequest, request_options: options_mod.RequestOptions) !byok_mod.ListResponse {
        const client: *Client = @alignCast(@fieldParentPtr("byok", self));
        return byok_mod.list(client, request, request_options);
    }
    pub fn create(self: *ByokResource, request: byok_mod.CreateRequest, request_options: options_mod.RequestOptions) !byok_mod.CreateResponse {
        const client: *Client = @alignCast(@fieldParentPtr("byok", self));
        return byok_mod.create(client, request, request_options);
    }
    pub fn get(self: *ByokResource, id: []const u8, request_options: options_mod.RequestOptions) !byok_mod.GetResponse {
        const client: *Client = @alignCast(@fieldParentPtr("byok", self));
        return byok_mod.get(client, id, request_options);
    }
    pub fn update(self: *ByokResource, id: []const u8, request: byok_mod.UpdateRequest, request_options: options_mod.RequestOptions) !byok_mod.UpdateResponse {
        const client: *Client = @alignCast(@fieldParentPtr("byok", self));
        return byok_mod.update(client, id, request, request_options);
    }
    pub fn delete(self: *ByokResource, id: []const u8, request_options: options_mod.RequestOptions) !byok_mod.DeleteResponse {
        const client: *Client = @alignCast(@fieldParentPtr("byok", self));
        return byok_mod.delete(client, id, request_options);
    }
};
pub const GuardrailsResource = struct {
    pub fn list(self: *GuardrailsResource, request: guardrails_mod.ListRequest, request_options: options_mod.RequestOptions) !guardrails_mod.ListResponse {
        const client: *Client = @alignCast(@fieldParentPtr("guardrails", self));
        return guardrails_mod.list(client, request, request_options);
    }
    pub fn create(self: *GuardrailsResource, request: guardrails_mod.CreateRequest, request_options: options_mod.RequestOptions) !guardrails_mod.CreateResponse {
        const client: *Client = @alignCast(@fieldParentPtr("guardrails", self));
        return guardrails_mod.create(client, request, request_options);
    }
    pub fn get(self: *GuardrailsResource, id: []const u8, request_options: options_mod.RequestOptions) !guardrails_mod.GetResponse {
        const client: *Client = @alignCast(@fieldParentPtr("guardrails", self));
        return guardrails_mod.get(client, id, request_options);
    }
    pub fn update(self: *GuardrailsResource, id: []const u8, request: guardrails_mod.UpdateRequest, request_options: options_mod.RequestOptions) !guardrails_mod.UpdateResponse {
        const client: *Client = @alignCast(@fieldParentPtr("guardrails", self));
        return guardrails_mod.update(client, id, request, request_options);
    }
    pub fn delete(self: *GuardrailsResource, id: []const u8, request_options: options_mod.RequestOptions) !guardrails_mod.DeleteResponse {
        const client: *Client = @alignCast(@fieldParentPtr("guardrails", self));
        return guardrails_mod.delete(client, id, request_options);
    }
    pub fn listKeyAssignments(self: *GuardrailsResource, request: guardrails_mod.AssignmentListRequest, request_options: options_mod.RequestOptions) !guardrails_mod.KeyAssignmentsListResponse {
        const client: *Client = @alignCast(@fieldParentPtr("guardrails", self));
        return guardrails_mod.listKeyAssignments(client, request, request_options);
    }
    pub fn listGuardrailKeyAssignments(self: *GuardrailsResource, id: []const u8, request: guardrails_mod.AssignmentListRequest, request_options: options_mod.RequestOptions) !guardrails_mod.KeyAssignmentsListResponse {
        const client: *Client = @alignCast(@fieldParentPtr("guardrails", self));
        return guardrails_mod.listGuardrailKeyAssignments(client, id, request, request_options);
    }
    pub fn bulkAssignKeys(self: *GuardrailsResource, id: []const u8, request: guardrails_mod.BulkKeyAssignmentRequest, request_options: options_mod.RequestOptions) !guardrails_mod.BulkAssignResponse {
        const client: *Client = @alignCast(@fieldParentPtr("guardrails", self));
        return guardrails_mod.bulkAssignKeys(client, id, request, request_options);
    }
    pub fn bulkUnassignKeys(self: *GuardrailsResource, id: []const u8, request: guardrails_mod.BulkKeyAssignmentRequest, request_options: options_mod.RequestOptions) !guardrails_mod.BulkUnassignResponse {
        const client: *Client = @alignCast(@fieldParentPtr("guardrails", self));
        return guardrails_mod.bulkUnassignKeys(client, id, request, request_options);
    }
    pub fn listMemberAssignments(self: *GuardrailsResource, request: guardrails_mod.AssignmentListRequest, request_options: options_mod.RequestOptions) !guardrails_mod.MemberAssignmentsListResponse {
        const client: *Client = @alignCast(@fieldParentPtr("guardrails", self));
        return guardrails_mod.listMemberAssignments(client, request, request_options);
    }
    pub fn listGuardrailMemberAssignments(self: *GuardrailsResource, id: []const u8, request: guardrails_mod.AssignmentListRequest, request_options: options_mod.RequestOptions) !guardrails_mod.MemberAssignmentsListResponse {
        const client: *Client = @alignCast(@fieldParentPtr("guardrails", self));
        return guardrails_mod.listGuardrailMemberAssignments(client, id, request, request_options);
    }
    pub fn bulkAssignMembers(self: *GuardrailsResource, id: []const u8, request: guardrails_mod.BulkMemberAssignmentRequest, request_options: options_mod.RequestOptions) !guardrails_mod.BulkAssignResponse {
        const client: *Client = @alignCast(@fieldParentPtr("guardrails", self));
        return guardrails_mod.bulkAssignMembers(client, id, request, request_options);
    }
    pub fn bulkUnassignMembers(self: *GuardrailsResource, id: []const u8, request: guardrails_mod.BulkMemberAssignmentRequest, request_options: options_mod.RequestOptions) !guardrails_mod.BulkUnassignResponse {
        const client: *Client = @alignCast(@fieldParentPtr("guardrails", self));
        return guardrails_mod.bulkUnassignMembers(client, id, request, request_options);
    }
};
pub const WorkspacesResource = struct {
    budgets: WorkspaceBudgetsResource = .{},
    members: WorkspaceMembersResource = .{},

    pub fn list(self: *WorkspacesResource, request: workspaces_mod.ListRequest, request_options: options_mod.RequestOptions) !workspaces_mod.ListResponse {
        const client: *Client = @alignCast(@fieldParentPtr("workspaces", self));
        return workspaces_mod.list(client, request, request_options);
    }
    pub fn create(self: *WorkspacesResource, request: workspaces_mod.CreateRequest, request_options: options_mod.RequestOptions) !workspaces_mod.CreateResponse {
        const client: *Client = @alignCast(@fieldParentPtr("workspaces", self));
        return workspaces_mod.create(client, request, request_options);
    }
    pub fn get(self: *WorkspacesResource, id: []const u8, request_options: options_mod.RequestOptions) !workspaces_mod.GetResponse {
        const client: *Client = @alignCast(@fieldParentPtr("workspaces", self));
        return workspaces_mod.get(client, id, request_options);
    }
    pub fn update(self: *WorkspacesResource, id: []const u8, request: workspaces_mod.UpdateRequest, request_options: options_mod.RequestOptions) !workspaces_mod.UpdateResponse {
        const client: *Client = @alignCast(@fieldParentPtr("workspaces", self));
        return workspaces_mod.update(client, id, request, request_options);
    }
    pub fn delete(self: *WorkspacesResource, id: []const u8, request_options: options_mod.RequestOptions) !workspaces_mod.DeleteResponse {
        const client: *Client = @alignCast(@fieldParentPtr("workspaces", self));
        return workspaces_mod.delete(client, id, request_options);
    }
    pub fn bulkAddMembers(self: *WorkspacesResource, id: []const u8, request: workspaces_mod.BulkMembersRequest, request_options: options_mod.RequestOptions) !workspaces_mod.BulkAddMembersResponse {
        const client: *Client = @alignCast(@fieldParentPtr("workspaces", self));
        return workspaces_mod.bulkAddMembers(client, id, request, request_options);
    }
    pub fn bulkRemoveMembers(self: *WorkspacesResource, id: []const u8, request: workspaces_mod.BulkMembersRequest, request_options: options_mod.RequestOptions) !workspaces_mod.BulkRemoveMembersResponse {
        const client: *Client = @alignCast(@fieldParentPtr("workspaces", self));
        return workspaces_mod.bulkRemoveMembers(client, id, request, request_options);
    }
};
pub const WorkspaceMembersResource = struct {
    pub fn list(self: *WorkspaceMembersResource, workspace_ref: []const u8, request: workspaces_mod.MembersListRequest, request_options: options_mod.RequestOptions) !workspaces_mod.MembersListResponse {
        const workspaces: *WorkspacesResource = @alignCast(@fieldParentPtr("members", self));
        const client: *Client = @alignCast(@fieldParentPtr("workspaces", workspaces));
        return workspaces_mod.listMembers(client, workspace_ref, request, request_options);
    }
};
pub const WorkspaceBudgetsResource = struct {
    pub fn list(self: *WorkspaceBudgetsResource, id: []const u8, request_options: options_mod.RequestOptions) !workspaces_mod.BudgetListResponse {
        const workspaces: *WorkspacesResource = @alignCast(@fieldParentPtr("budgets", self));
        const client: *Client = @alignCast(@fieldParentPtr("workspaces", workspaces));
        return workspaces_mod.listBudgets(client, id, request_options);
    }
    pub fn get(self: *WorkspaceBudgetsResource, workspace_ref: []const u8, interval: workspaces_mod.BudgetInterval, request_options: options_mod.RequestOptions) !workspaces_mod.BudgetGetResponse {
        const workspaces: *WorkspacesResource = @alignCast(@fieldParentPtr("budgets", self));
        const client: *Client = @alignCast(@fieldParentPtr("workspaces", workspaces));
        return workspaces_mod.getBudget(client, workspace_ref, interval, request_options);
    }
    pub fn upsert(self: *WorkspaceBudgetsResource, id: []const u8, interval: workspaces_mod.BudgetInterval, request: workspaces_mod.BudgetUpsertRequest, request_options: options_mod.RequestOptions) !workspaces_mod.BudgetUpsertResponse {
        const workspaces: *WorkspacesResource = @alignCast(@fieldParentPtr("budgets", self));
        const client: *Client = @alignCast(@fieldParentPtr("workspaces", workspaces));
        return workspaces_mod.upsertBudget(client, id, interval, request, request_options);
    }
    pub fn delete(self: *WorkspaceBudgetsResource, id: []const u8, interval: workspaces_mod.BudgetInterval, request_options: options_mod.RequestOptions) !workspaces_mod.BudgetDeleteResponse {
        const workspaces: *WorkspacesResource = @alignCast(@fieldParentPtr("budgets", self));
        const client: *Client = @alignCast(@fieldParentPtr("workspaces", workspaces));
        return workspaces_mod.deleteBudget(client, id, interval, request_options);
    }
};
pub const ObservabilityResource = struct {
    destinations: ObservabilityDestinationsResource = .{},
};
pub const ObservabilityDestinationsResource = struct {
    pub fn list(self: *ObservabilityDestinationsResource, request: observability_mod.ListRequest, request_options: options_mod.RequestOptions) !observability_mod.ListResponse {
        const observability: *ObservabilityResource = @alignCast(@fieldParentPtr("destinations", self));
        const client: *Client = @alignCast(@fieldParentPtr("observability", observability));
        return observability_mod.list(client, request, request_options);
    }
    pub fn create(self: *ObservabilityDestinationsResource, request: observability_mod.CreateRequest, request_options: options_mod.RequestOptions) !observability_mod.CreateResponse {
        const observability: *ObservabilityResource = @alignCast(@fieldParentPtr("destinations", self));
        const client: *Client = @alignCast(@fieldParentPtr("observability", observability));
        return observability_mod.create(client, request, request_options);
    }
    pub fn get(self: *ObservabilityDestinationsResource, id: []const u8, request_options: options_mod.RequestOptions) !observability_mod.GetResponse {
        const observability: *ObservabilityResource = @alignCast(@fieldParentPtr("destinations", self));
        const client: *Client = @alignCast(@fieldParentPtr("observability", observability));
        return observability_mod.get(client, id, request_options);
    }
    pub fn update(self: *ObservabilityDestinationsResource, id: []const u8, request: observability_mod.UpdateRequest, request_options: options_mod.RequestOptions) !observability_mod.UpdateResponse {
        const observability: *ObservabilityResource = @alignCast(@fieldParentPtr("destinations", self));
        const client: *Client = @alignCast(@fieldParentPtr("observability", observability));
        return observability_mod.update(client, id, request, request_options);
    }
    pub fn delete(self: *ObservabilityDestinationsResource, id: []const u8, request_options: options_mod.RequestOptions) !observability_mod.DeleteResponse {
        const observability: *ObservabilityResource = @alignCast(@fieldParentPtr("destinations", self));
        const client: *Client = @alignCast(@fieldParentPtr("observability", observability));
        return observability_mod.delete(client, id, request_options);
    }
};
pub const ScimResource = struct {
    pub fn listMappings(self: *ScimResource, request: scim_mod.ListMappingsRequest, request_options: options_mod.RequestOptions) !scim_mod.ListMappingsResponse {
        const client: *Client = @alignCast(@fieldParentPtr("scim", self));
        return scim_mod.listMappings(client, request, request_options);
    }
    pub fn listGroups(self: *ScimResource, request: scim_mod.ListGroupsRequest, request_options: options_mod.RequestOptions) !scim_mod.ListGroupsResponse {
        const client: *Client = @alignCast(@fieldParentPtr("scim", self));
        return scim_mod.listGroups(client, request, request_options);
    }
    pub fn createMapping(self: *ScimResource, request: scim_mod.CreateMappingRequest, request_options: options_mod.RequestOptions) !scim_mod.MappingResponse {
        const client: *Client = @alignCast(@fieldParentPtr("scim", self));
        return scim_mod.createMapping(client, request, request_options);
    }
    pub fn getMapping(self: *ScimResource, id: []const u8, request_options: options_mod.RequestOptions) !scim_mod.MappingResponse {
        const client: *Client = @alignCast(@fieldParentPtr("scim", self));
        return scim_mod.getMapping(client, id, request_options);
    }
    pub fn updateMapping(self: *ScimResource, id: []const u8, request: scim_mod.UpdateMappingRequest, request_options: options_mod.RequestOptions) !scim_mod.MappingResponse {
        const client: *Client = @alignCast(@fieldParentPtr("scim", self));
        return scim_mod.updateMapping(client, id, request, request_options);
    }
    pub fn deleteMapping(self: *ScimResource, id: []const u8, request: scim_mod.DeleteMappingRequest, request_options: options_mod.RequestOptions) !scim_mod.DeleteMappingResponse {
        const client: *Client = @alignCast(@fieldParentPtr("scim", self));
        return scim_mod.deleteMapping(client, id, request, request_options);
    }
    pub fn createSyncJob(self: *ScimResource, request_options: options_mod.RequestOptions) !scim_mod.SyncJobResponse {
        const client: *Client = @alignCast(@fieldParentPtr("scim", self));
        return scim_mod.createSyncJob(client, request_options);
    }
    pub fn getSyncJob(self: *ScimResource, id: []const u8, request_options: options_mod.RequestOptions) !scim_mod.SyncJobResponse {
        const client: *Client = @alignCast(@fieldParentPtr("scim", self));
        return scim_mod.getSyncJob(client, id, request_options);
    }
};

pub const PrivateEndpointsResource = struct {
    pub fn create(self: *PrivateEndpointsResource, request: private_endpoints_mod.CreateRequest, request_options: options_mod.RequestOptions) !private_endpoints_mod.CreateResponse {
        const client: *Client = @alignCast(@fieldParentPtr("private_endpoints", self));
        return private_endpoints_mod.create(client, request, request_options);
    }

    pub fn updatePricing(self: *PrivateEndpointsResource, id: []const u8, request: private_endpoints_mod.UpdatePricingRequest, request_options: options_mod.RequestOptions) !private_endpoints_mod.GetResponse {
        const client: *Client = @alignCast(@fieldParentPtr("private_endpoints", self));
        return private_endpoints_mod.updatePricing(client, id, request, request_options);
    }

    pub fn validate(self: *PrivateEndpointsResource, id: []const u8, request: private_endpoints_mod.ValidateRequest, request_options: options_mod.RequestOptions) !private_endpoints_mod.ValidationResponse {
        const client: *Client = @alignCast(@fieldParentPtr("private_endpoints", self));
        return private_endpoints_mod.validate(client, id, request, request_options);
    }

    pub fn enable(self: *PrivateEndpointsResource, id: []const u8, request_options: options_mod.RequestOptions) !private_endpoints_mod.ManagedResponse {
        const client: *Client = @alignCast(@fieldParentPtr("private_endpoints", self));
        return private_endpoints_mod.enable(client, id, request_options);
    }

    pub fn disable(self: *PrivateEndpointsResource, id: []const u8, request_options: options_mod.RequestOptions) !private_endpoints_mod.ManagedResponse {
        const client: *Client = @alignCast(@fieldParentPtr("private_endpoints", self));
        return private_endpoints_mod.disable(client, id, request_options);
    }

    pub fn activate(self: *PrivateEndpointsResource, id: []const u8, request_options: options_mod.RequestOptions) !private_endpoints_mod.ManagedResponse {
        const client: *Client = @alignCast(@fieldParentPtr("private_endpoints", self));
        return private_endpoints_mod.activate(client, id, request_options);
    }

    pub fn delete(self: *PrivateEndpointsResource, id: []const u8, request_options: options_mod.RequestOptions) !private_endpoints_mod.DeleteResponse {
        const client: *Client = @alignCast(@fieldParentPtr("private_endpoints", self));
        return private_endpoints_mod.delete(client, id, request_options);
    }

    pub fn update(self: *PrivateEndpointsResource, id: []const u8, request: private_endpoints_mod.UpdateRequest, request_options: options_mod.RequestOptions) !private_endpoints_mod.GetResponse {
        const client: *Client = @alignCast(@fieldParentPtr("private_endpoints", self));
        return private_endpoints_mod.update(client, id, request, request_options);
    }

    pub fn list(self: *PrivateEndpointsResource, request_options: options_mod.RequestOptions) !private_endpoints_mod.ListResponse {
        const client: *Client = @alignCast(@fieldParentPtr("private_endpoints", self));
        return private_endpoints_mod.list(client, request_options);
    }
    pub fn get(self: *PrivateEndpointsResource, id: []const u8, request_options: options_mod.RequestOptions) !private_endpoints_mod.GetResponse {
        const client: *Client = @alignCast(@fieldParentPtr("private_endpoints", self));
        return private_endpoints_mod.get(client, id, request_options);
    }
};
pub const OrganizationResource = struct {
    members: OrganizationMembersResource = .{},
    settings: OrganizationSettingsResource = .{},
};
pub const OrganizationSettingsResource = struct {
    pub fn get(self: *OrganizationSettingsResource, request_options: options_mod.RequestOptions) !organization_mod.SettingsResponse {
        const organization: *OrganizationResource = @alignCast(@fieldParentPtr("settings", self));
        const client: *Client = @alignCast(@fieldParentPtr("organization", organization));
        return organization_mod.getSettings(client, request_options);
    }
    pub fn update(self: *OrganizationSettingsResource, request: organization_mod.SettingsUpdateRequest, request_options: options_mod.RequestOptions) !organization_mod.SettingsResponse {
        const organization: *OrganizationResource = @alignCast(@fieldParentPtr("settings", self));
        const client: *Client = @alignCast(@fieldParentPtr("organization", organization));
        return organization_mod.updateSettings(client, request, request_options);
    }
};
pub const OrganizationMembersResource = struct {
    pub fn list(self: *OrganizationMembersResource, request: organization_mod.MembersListRequest, request_options: options_mod.RequestOptions) !organization_mod.MembersListResponse {
        const organization: *OrganizationResource = @alignCast(@fieldParentPtr("members", self));
        const client: *Client = @alignCast(@fieldParentPtr("organization", organization));
        return organization_mod.listMembers(client, request, request_options);
    }
};
pub const OAuthResource = struct {
    pub fn jwks(self: *OAuthResource, request_options: options_mod.RequestOptions) !oauth_mod.JwksResponse {
        const client: *Client = @alignCast(@fieldParentPtr("oauth", self));
        return oauth_mod.jwks(client, request_options);
    }
    pub fn exchangeToken(self: *OAuthResource, request: oauth_mod.TokenExchangeRequest, request_options: options_mod.RequestOptions) !oauth_mod.TokenExchangeResponse {
        const client: *Client = @alignCast(@fieldParentPtr("oauth", self));
        return oauth_mod.exchangeToken(client, request, request_options);
    }

    pub fn createAuthCode(self: *OAuthResource, request: auth_keys_mod.CreateCodeRequest, request_options: options_mod.RequestOptions) !auth_keys_mod.CreateCodeResponse {
        const client: *Client = @alignCast(@fieldParentPtr("oauth", self));
        return auth_keys_mod.createCode(client, request, request_options);
    }

    pub fn exchangeAuthCodeForAPIKey(self: *OAuthResource, request: auth_keys_mod.ExchangeRequest, request_options: options_mod.RequestOptions) !auth_keys_mod.ExchangeResponse {
        const client: *Client = @alignCast(@fieldParentPtr("oauth", self));
        return auth_keys_mod.exchange(client, request, request_options);
    }
};
pub const KeyResource = struct {
    pub fn get(self: *KeyResource, request_options: options_mod.RequestOptions) !key_mod.GetResponse {
        const client: *Client = @alignCast(@fieldParentPtr("key", self));
        return key_mod.get(client, request_options);
    }
};
pub const KeysResource = struct {
    pub fn list(self: *KeysResource, request: keys_mod.ListRequest, request_options: options_mod.RequestOptions) !keys_mod.ListResponse {
        const client: *Client = @alignCast(@fieldParentPtr("keys", self));
        return keys_mod.list(client, request, request_options);
    }
    pub fn create(self: *KeysResource, request: keys_mod.CreateRequest, request_options: options_mod.RequestOptions) !keys_mod.CreateResponse {
        const client: *Client = @alignCast(@fieldParentPtr("keys", self));
        return keys_mod.create(client, request, request_options);
    }
    pub fn get(self: *KeysResource, hash: []const u8, request_options: options_mod.RequestOptions) !keys_mod.GetResponse {
        const client: *Client = @alignCast(@fieldParentPtr("keys", self));
        return keys_mod.get(client, hash, request_options);
    }
    pub fn update(self: *KeysResource, hash: []const u8, request: keys_mod.UpdateRequest, request_options: options_mod.RequestOptions) !keys_mod.UpdateResponse {
        const client: *Client = @alignCast(@fieldParentPtr("keys", self));
        return keys_mod.update(client, hash, request, request_options);
    }
    pub fn delete(self: *KeysResource, hash: []const u8, request_options: options_mod.RequestOptions) !keys_mod.DeleteResponse {
        const client: *Client = @alignCast(@fieldParentPtr("keys", self));
        return keys_mod.delete(client, hash, request_options);
    }
};
pub const ProvidersResource = struct {
    pub fn list(self: *ProvidersResource, request_options: options_mod.RequestOptions) !providers_mod.ListResponse {
        const client: *Client = @alignCast(@fieldParentPtr("providers", self));
        return providers_mod.list(client, request_options);
    }
};
pub const BenchmarksResource = struct {
    pub fn list(self: *BenchmarksResource, request: benchmarks_mod.ListRequest, request_options: options_mod.RequestOptions) !benchmarks_mod.ListResponse {
        const client: *Client = @alignCast(@fieldParentPtr("benchmarks", self));
        return benchmarks_mod.list(client, request, request_options);
    }
};
pub const ClassificationsResource = struct { task: ClassificationsTaskResource = .{} };
pub const ClassificationsTaskResource = struct {
    pub fn get(self: *ClassificationsTaskResource, request: classifications_mod.TaskGetRequest, request_options: options_mod.RequestOptions) !classifications_mod.TaskGetResponse {
        const classifications: *ClassificationsResource = @alignCast(@fieldParentPtr("task", self));
        const client: *Client = @alignCast(@fieldParentPtr("classifications", classifications));
        return classifications_mod.get(client, request, request_options);
    }
};
pub const GenerationResource = struct {
    pub fn get(
        self: *GenerationResource,
        request: generation_mod.GetRequest,
        request_options: options_mod.RequestOptions,
    ) !generation_mod.GetResponse {
        const client: *Client = @alignCast(@fieldParentPtr("generation", self));
        return generation_mod.get(client, request, request_options);
    }

    pub fn content(
        self: *GenerationResource,
        request: generation_mod.ContentRequest,
        request_options: options_mod.RequestOptions,
    ) !generation_mod.ContentResponse {
        const client: *Client = @alignCast(@fieldParentPtr("generation", self));
        return generation_mod.content(client, request, request_options);
    }

    pub fn feedback(
        self: *GenerationResource,
        request: generation_mod.FeedbackRequest,
        request_options: options_mod.RequestOptions,
    ) !generation_mod.FeedbackResponse {
        const client: *Client = @alignCast(@fieldParentPtr("generation", self));
        return generation_mod.feedback(client, request, request_options);
    }
};
pub const ActivityResource = struct {
    pub fn get(self: *ActivityResource, request: activity_mod.GetRequest, request_options: options_mod.RequestOptions) !activity_mod.GetResponse {
        const client: *Client = @alignCast(@fieldParentPtr("activity", self));
        return activity_mod.get(client, request, request_options);
    }
};
pub const AnalyticsResource = struct {
    meta: AnalyticsMetaResource = .{},

    pub fn query(self: *AnalyticsResource, request: analytics_mod.QueryRequest, request_options: options_mod.RequestOptions) !analytics_mod.QueryResponse {
        const client: *Client = @alignCast(@fieldParentPtr("analytics", self));
        return analytics_mod.query(client, request, request_options);
    }
};
pub const AnalyticsMetaResource = struct {
    pub fn get(self: *AnalyticsMetaResource, request_options: options_mod.RequestOptions) !analytics_mod.MetaGetResponse {
        const analytics: *AnalyticsResource = @alignCast(@fieldParentPtr("meta", self));
        const client: *Client = @alignCast(@fieldParentPtr("analytics", analytics));
        return analytics_mod.getMeta(client, request_options);
    }
};
pub const DatasetsResource = struct {
    app_rankings: AppRankingsResource = .{},
    benchmarks: DatasetBenchmarksResource = .{},
    rankings_daily: RankingsDailyResource = .{},
    session_cost: SessionCostResource = .{},
};
pub const AppRankingsResource = struct {
    pub fn get(
        self: *AppRankingsResource,
        request: datasets_mod.AppRankingsGetRequest,
        request_options: options_mod.RequestOptions,
    ) !datasets_mod.AppRankingsGetResponse {
        const datasets: *DatasetsResource = @alignCast(@fieldParentPtr("app_rankings", self));
        const client: *Client = @alignCast(@fieldParentPtr("datasets", datasets));
        return datasets_mod.getAppRankings(client, request, request_options);
    }
};
pub const DatasetBenchmarksResource = struct {
    artificial_analysis: DatasetBenchmarksArtificialAnalysisResource = .{},
    design_arena: DatasetBenchmarksDesignArenaResource = .{},
};
pub const DatasetBenchmarksArtificialAnalysisResource = struct {
    pub fn get(
        self: *DatasetBenchmarksArtificialAnalysisResource,
        request: datasets_mod.BenchmarksArtificialAnalysisGetRequest,
        request_options: options_mod.RequestOptions,
    ) !datasets_mod.BenchmarksArtificialAnalysisGetResponse {
        const benchmarks: *DatasetBenchmarksResource = @alignCast(@fieldParentPtr("artificial_analysis", self));
        const datasets: *DatasetsResource = @alignCast(@fieldParentPtr("benchmarks", benchmarks));
        const client: *Client = @alignCast(@fieldParentPtr("datasets", datasets));
        return datasets_mod.getBenchmarksArtificialAnalysis(client, request, request_options);
    }
};
pub const DatasetBenchmarksDesignArenaResource = struct {
    pub fn get(
        self: *DatasetBenchmarksDesignArenaResource,
        request: datasets_mod.BenchmarksDesignArenaGetRequest,
        request_options: options_mod.RequestOptions,
    ) !datasets_mod.BenchmarksDesignArenaGetResponse {
        const benchmarks: *DatasetBenchmarksResource = @alignCast(@fieldParentPtr("design_arena", self));
        const datasets: *DatasetsResource = @alignCast(@fieldParentPtr("benchmarks", benchmarks));
        const client: *Client = @alignCast(@fieldParentPtr("datasets", datasets));
        return datasets_mod.getBenchmarksDesignArena(client, request, request_options);
    }
};
pub const RankingsDailyResource = struct {
    pub fn get(
        self: *RankingsDailyResource,
        request: datasets_mod.RankingsDailyGetRequest,
        request_options: options_mod.RequestOptions,
    ) !datasets_mod.RankingsDailyGetResponse {
        const datasets: *DatasetsResource = @alignCast(@fieldParentPtr("rankings_daily", self));
        const client: *Client = @alignCast(@fieldParentPtr("datasets", datasets));
        return datasets_mod.getRankingsDaily(client, request, request_options);
    }
};
pub const SessionCostResource = struct {
    pub fn get(
        self: *SessionCostResource,
        request: datasets_mod.SessionCostRequest,
        request_options: options_mod.RequestOptions,
    ) !datasets_mod.SessionCostResponse {
        const datasets: *DatasetsResource = @alignCast(@fieldParentPtr("session_cost", self));
        const client: *Client = @alignCast(@fieldParentPtr("datasets", datasets));
        return datasets_mod.getSessionCost(client, request, request_options);
    }
};

/// Root OpenRouter client.
///
/// A `Client` owns its HTTP connection pool and is not thread-safe unless the
/// caller externally synchronizes access or uses one client per worker.
pub const VaultResource = struct {
    pub fn listSecrets(self: *VaultResource, request: vault_mod.ListRequest, request_options: options_mod.RequestOptions) !vault_mod.ListSecretsResponse {
        const client: *Client = @alignCast(@fieldParentPtr("vault", self));
        return vault_mod.listSecrets(client, request, request_options);
    }
    pub fn putSecret(self: *VaultResource, name: []const u8, request: vault_mod.WriteRequest, request_options: options_mod.RequestOptions) !vault_mod.PutSecretResponse {
        const client: *Client = @alignCast(@fieldParentPtr("vault", self));
        return vault_mod.putSecret(client, name, request, request_options);
    }
    pub fn deleteSecret(self: *VaultResource, name: []const u8, request_options: options_mod.RequestOptions) !vault_mod.DeleteSecretResponse {
        const client: *Client = @alignCast(@fieldParentPtr("vault", self));
        return vault_mod.deleteSecret(client, name, request_options);
    }
    pub fn listInternSecrets(self: *VaultResource, id: []const u8, request: vault_mod.ListRequest, request_options: options_mod.RequestOptions) !vault_mod.ListInternSecretsResponse {
        const client: *Client = @alignCast(@fieldParentPtr("vault", self));
        return vault_mod.listInternSecrets(client, id, request, request_options);
    }
    pub fn listEffectiveSecrets(self: *VaultResource, id: []const u8, request: vault_mod.ListRequest, request_options: options_mod.RequestOptions) !vault_mod.ListEffectiveSecretsResponse {
        const client: *Client = @alignCast(@fieldParentPtr("vault", self));
        return vault_mod.listEffectiveSecrets(client, id, request, request_options);
    }
    pub fn putInternSecret(self: *VaultResource, id: []const u8, name: []const u8, request: vault_mod.WriteRequest, request_options: options_mod.RequestOptions) !vault_mod.PutInternSecretResponse {
        const client: *Client = @alignCast(@fieldParentPtr("vault", self));
        return vault_mod.putInternSecret(client, id, name, request, request_options);
    }
    pub fn deleteInternSecret(self: *VaultResource, id: []const u8, name: []const u8, request_options: options_mod.RequestOptions) !vault_mod.DeleteInternSecretResponse {
        const client: *Client = @alignCast(@fieldParentPtr("vault", self));
        return vault_mod.deleteInternSecret(client, id, name, request_options);
    }
    pub fn copySecrets(self: *VaultResource, id: []const u8, request: vault_mod.CopyRequest, request_options: options_mod.RequestOptions) !vault_mod.CopySecretsResponse {
        const client: *Client = @alignCast(@fieldParentPtr("vault", self));
        return vault_mod.copySecrets(client, id, request, request_options);
    }
};

pub const ContainersResource = struct {
    pub fn content(self: *ContainersResource, container_id: []const u8, file_id: []const u8, request_options: options_mod.RequestOptions) !containers_mod.ContentResponse {
        const client: *Client = @alignCast(@fieldParentPtr("containers", self));
        return containers_mod.content(client, container_id, file_id, request_options);
    }

    pub fn listFiles(self: *ContainersResource, container_id: []const u8, request: containers_mod.ListRequest, request_options: options_mod.RequestOptions) !containers_mod.ListFilesResponse {
        const client: *Client = @alignCast(@fieldParentPtr("containers", self));
        return containers_mod.listFiles(client, container_id, request, request_options);
    }
    pub fn getFile(self: *ContainersResource, container_id: []const u8, file_id: []const u8, request_options: options_mod.RequestOptions) !containers_mod.GetFileResponse {
        const client: *Client = @alignCast(@fieldParentPtr("containers", self));
        return containers_mod.getFile(client, container_id, file_id, request_options);
    }
    pub fn promoteFile(self: *ContainersResource, container_id: []const u8, file_id: []const u8, request_options: options_mod.RequestOptions) !containers_mod.PromoteFileResponse {
        const client: *Client = @alignCast(@fieldParentPtr("containers", self));
        return containers_mod.promoteFile(client, container_id, file_id, request_options);
    }
};

pub const InternsResource = struct {
    pub fn chat(self: *InternsResource, id: []const u8, request: interns_mod.ChatRequest, request_options: options_mod.RequestOptions) !interns_mod.ChatResponse {
        const client: *Client = @alignCast(@fieldParentPtr("interns", self));
        return interns_mod.chat(client, id, request, request_options);
    }

    pub fn list(self: *InternsResource, request: interns_mod.ListRequest, request_options: options_mod.RequestOptions) !interns_mod.ListResponse {
        const client: *Client = @alignCast(@fieldParentPtr("interns", self));
        return interns_mod.list(client, request, request_options);
    }
    pub fn create(self: *InternsResource, request: interns_mod.CreateRequest, request_options: options_mod.RequestOptions) !interns_mod.CreateResponse {
        const client: *Client = @alignCast(@fieldParentPtr("interns", self));
        return interns_mod.create(client, request, request_options);
    }
    pub fn get(self: *InternsResource, id: []const u8, request_options: options_mod.RequestOptions) !interns_mod.GetResponse {
        const client: *Client = @alignCast(@fieldParentPtr("interns", self));
        return interns_mod.get(client, id, request_options);
    }
    pub fn update(self: *InternsResource, id: []const u8, request: interns_mod.UpdateRequest, request_options: options_mod.RequestOptions) !interns_mod.UpdateResponse {
        const client: *Client = @alignCast(@fieldParentPtr("interns", self));
        return interns_mod.update(client, id, request, request_options);
    }
    pub fn delete(self: *InternsResource, id: []const u8, request: interns_mod.DeleteRequest, request_options: options_mod.RequestOptions) !interns_mod.DeleteResponse {
        const client: *Client = @alignCast(@fieldParentPtr("interns", self));
        return interns_mod.delete(client, id, request, request_options);
    }
    pub fn getDaemon(self: *InternsResource, id: []const u8, request_options: options_mod.RequestOptions) !interns_mod.GetDaemonResponse {
        const client: *Client = @alignCast(@fieldParentPtr("interns", self));
        return interns_mod.getDaemon(client, id, request_options);
    }
    pub fn signDaemon(self: *InternsResource, id: []const u8, request: interns_mod.SignRequest, request_options: options_mod.RequestOptions) !interns_mod.SignDaemonResponse {
        const client: *Client = @alignCast(@fieldParentPtr("interns", self));
        return interns_mod.signDaemon(client, id, request, request_options);
    }
    pub fn invoke(self: *InternsResource, id: []const u8, request: interns_mod.InvokeRequest, request_options: options_mod.RequestOptions) !interns_mod.InvokeResponse {
        const client: *Client = @alignCast(@fieldParentPtr("interns", self));
        return interns_mod.invoke(client, id, request, request_options);
    }
    pub fn provision(self: *InternsResource, id: []const u8, request_options: options_mod.RequestOptions) !interns_mod.ProvisionResponse {
        const client: *Client = @alignCast(@fieldParentPtr("interns", self));
        return interns_mod.provision(client, id, request_options);
    }
    pub fn suspendIntern(self: *InternsResource, id: []const u8, request_options: options_mod.RequestOptions) !interns_mod.SuspendResponse {
        const client: *Client = @alignCast(@fieldParentPtr("interns", self));
        return interns_mod.suspendIntern(client, id, request_options);
    }
};

pub const SystemOneResource = struct {
    pub fn create(self: *SystemOneResource, request: decisions_mod.Request, request_options: options_mod.RequestOptions) !decisions_mod.Response {
        const client: *Client = @alignCast(@fieldParentPtr("systemone", self));
        return decisions_mod.create(client, request, request_options);
    }
};
pub const DecisionsResource = struct {
    pub fn create(self: *DecisionsResource, request: decisions_mod.Request, request_options: options_mod.RequestOptions) !decisions_mod.Response {
        const alpha_resource: *AlphaResource = @alignCast(@fieldParentPtr("decisions", self));
        const client: *Client = @alignCast(@fieldParentPtr("alpha", alpha_resource));
        return decisions_mod.alpha(client, request, request_options);
    }
};
pub const AlphaResource = struct { decisions: DecisionsResource = .{} };

pub const Client = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    config: Config,
    base_uri: std.Uri,
    http_client: std.http.Client,
    chat: ChatResource,
    audio: AudioResource,
    models: ModelsResource,
    embeddings: EmbeddingsResource,
    end_users: EndUsersResource,
    batches: BatchesResource,
    images: ImagesResource,
    endpoints: EndpointsResource,
    files: FilesResource,
    videos: VideosResource,
    presets: PresetsResource,
    rerank: RerankResource,
    responses: ResponsesResource,
    messages: MessagesResource,
    credits: CreditsResource,
    byok: ByokResource,
    guardrails: GuardrailsResource,
    workspaces: WorkspacesResource,
    observability: ObservabilityResource,
    organization: OrganizationResource,
    scim: ScimResource,
    vault: VaultResource,
    containers: ContainersResource,
    interns: InternsResource,
    systemone: SystemOneResource,
    alpha: AlphaResource,
    private_endpoints: PrivateEndpointsResource,
    oauth: OAuthResource,
    key: KeyResource,
    keys: KeysResource,
    providers: ProvidersResource,
    benchmarks: BenchmarksResource,
    classifications: ClassificationsResource,
    generation: GenerationResource,
    activity: ActivityResource,
    analytics: AnalyticsResource,
    datasets: DatasetsResource,
    tools: ToolsResource,

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
            .audio = .{},
            .models = .{},
            .embeddings = .{},
            .end_users = .{},
            .batches = .{},
            .images = .{},
            .endpoints = .{},
            .files = .{},
            .videos = .{},
            .presets = .{},
            .rerank = .{},
            .responses = .{},
            .messages = .{},
            .credits = .{},
            .byok = .{},
            .guardrails = .{},
            .workspaces = .{},
            .observability = .{},
            .organization = .{},
            .scim = .{},
            .vault = .{},
            .containers = .{},
            .interns = .{},
            .systemone = .{},
            .alpha = .{},
            .private_endpoints = .{},
            .oauth = .{},
            .key = .{},
            .keys = .{},
            .providers = .{},
            .benchmarks = .{},
            .classifications = .{},
            .generation = .{},
            .activity = .{},
            .analytics = .{},
            .datasets = .{},
            .tools = .{},
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
    var client = try Client.init(std.testing.allocator, std.testing.io, .{
        .api_key = "test-key",
    });
    defer client.deinit();

    try std.testing.expectEqualStrings("test-key", client.config.api_key);
    try std.testing.expectEqualStrings("https", client.base_uri.scheme);
}

test "client supports custom base URL" {
    var client = try Client.init(std.testing.allocator, std.testing.io, .{
        .api_key = "test-key",
        .base_url = "http://localhost:8080/api/v1",
    });
    defer client.deinit();

    try std.testing.expectEqualStrings("http", client.base_uri.scheme);
    try std.testing.expect(client.base_uri.host != null);
}

test "client stores optional attribution headers" {
    var client = try Client.init(std.testing.allocator, std.testing.io, .{
        .api_key = "test-key",
        .http_referer = "https://example.com",
        .x_title = "openrouter-zig-test",
    });
    defer client.deinit();

    try std.testing.expectEqualStrings("https://example.com", client.config.http_referer.?);
    try std.testing.expectEqualStrings("openrouter-zig-test", client.config.x_title.?);
}

test "client exposes OAuth resource" {
    var client = try Client.init(std.testing.allocator, std.testing.io, .{ .api_key = "test-key" });
    defer client.deinit();

    _ = &client.oauth;
}

test "client exposes OAuth helper methods" {
    var client = try Client.init(std.testing.allocator, std.testing.io, .{ .api_key = "test-key" });
    defer client.deinit();

    _ = &client.oauth;
    _ = OAuthResource.createAuthCode;
    _ = OAuthResource.exchangeAuthCodeForAPIKey;
}

test "client rejects invalid base URL" {
    try std.testing.expectError(error.InvalidBaseUrl, Client.init(std.testing.allocator, std.testing.io, .{
        .api_key = "test-key",
        .base_url = "not a url",
    }));
    try std.testing.expectError(error.InvalidBaseUrl, Client.init(std.testing.allocator, std.testing.io, .{
        .api_key = "test-key",
        .base_url = "ftp://example.com",
    }));
}

test "client rejects empty API key" {
    try std.testing.expectError(error.EmptyApiKey, Client.init(std.testing.allocator, std.testing.io, .{
        .api_key = "",
    }));
}

test "client initializes resource namespaces" {
    var client = try Client.init(std.testing.allocator, std.testing.io, .{
        .api_key = "test-key",
    });
    defer client.deinit();

    _ = client.chat;
    _ = client.chat.completions;
    _ = client.audio;
    _ = client.audio.speech;
    _ = client.audio.transcriptions;
    _ = client.models;
    _ = client.models.user;
    _ = client.models.endpoints;
    _ = client.embeddings;
    _ = client.embeddings.models;
    _ = client.end_users;
    _ = EndUsersResource.list;
    _ = EndUsersResource.create;
    _ = EndUsersResource.get;
    _ = EndUsersResource.update;
    _ = EndUsersResource.delete;
    _ = client.batches;
    _ = BatchesResource.list;
    _ = BatchesResource.create;
    _ = BatchesResource.get;
    _ = BatchesResource.delete;
    _ = client.images;
    _ = client.images.models;
    _ = client.images.models.endpoints;
    _ = ImagesResource.create;
    _ = ImagesModelsResource.list;
    _ = ImagesModelsEndpointsResource.list;
    _ = client.endpoints;
    _ = client.endpoints.zdr;
    _ = client.files;
    _ = client.videos;
    _ = client.videos.models;
    _ = client.presets;
    _ = client.presets.chat;
    _ = client.presets.chat.completions;
    _ = client.presets.messages;
    _ = client.presets.responses;
    _ = client.presets.versions;
    _ = client.rerank;
    _ = client.responses;
    _ = client.messages;
    _ = client.credits;
    _ = client.byok;
    _ = client.guardrails;
    _ = client.workspaces;
    _ = client.workspaces.budgets;
    _ = client.workspaces.members;
    _ = client.private_endpoints;
    _ = client.organization;
    _ = client.organization.members;
    _ = client.organization.settings;
    _ = client.key;
    _ = client.keys;
    _ = client.providers;
    _ = client.benchmarks;
    _ = client.classifications;
    _ = client.classifications.task;
    _ = client.generation;
    _ = GenerationResource.feedback;
    _ = client.activity;
    _ = client.analytics;
    _ = client.analytics.meta;
    _ = client.datasets;
    _ = client.datasets.app_rankings;
    _ = client.datasets.benchmarks;
    _ = client.datasets.benchmarks.artificial_analysis;
    _ = client.datasets.benchmarks.design_arena;
    _ = client.datasets.rankings_daily;
    _ = client.datasets.session_cost;
    _ = client.tools;
}

test "client.tools namespace exposes list and get" {
    var client = try Client.init(std.testing.allocator, std.testing.io, .{ .api_key = "test-key" });
    defer client.deinit();

    _ = client.tools;
    _ = ToolsResource.list;
    _ = ToolsResource.get;
}

test "client.datasets.session_cost namespace exposes get" {
    var client = try Client.init(std.testing.allocator, std.testing.io, .{
        .api_key = "test-key",
    });
    defer client.deinit();

    _ = client.datasets.session_cost;
    _ = SessionCostResource.get;
}

test "SCIM client calls forward request options before network IO" {
    var client = try Client.init(std.testing.allocator, std.testing.io, .{ .api_key = "test-key" });
    defer client.deinit();
    const invalid: options_mod.RequestOptions = .{ .extra_headers = &.{.{ .name = "Authorization", .value = "invalid" }} };
    try std.testing.expectError(error.OptionsInvalid, client.scim.listGroups(.{}, invalid));
    try std.testing.expectError(error.OptionsInvalid, client.scim.listMappings(.{}, invalid));
    try std.testing.expectError(error.OptionsInvalid, client.scim.createMapping(.{ .scim_group_id = "g", .workspace_id = "w", .role = .member }, invalid));
    try std.testing.expectError(error.OptionsInvalid, client.scim.getMapping("m", invalid));
    try std.testing.expectError(error.OptionsInvalid, client.scim.updateMapping("m", .{ .role = .admin }, invalid));
    try std.testing.expectError(error.OptionsInvalid, client.scim.deleteMapping("m", .{ .keep_members = true }, invalid));
    try std.testing.expectError(error.OptionsInvalid, client.scim.createSyncJob(invalid));
    try std.testing.expectError(error.OptionsInvalid, client.scim.getSyncJob("j", invalid));
}

test "Phase 3 client resources forward typed calls and request options" {
    var client = try Client.init(std.testing.allocator, std.testing.io, .{ .api_key = "test" });
    defer client.deinit();
    const invalid: options_mod.RequestOptions = .{ .extra_headers = &.{.{ .name = "Authorization", .value = "forbidden" }} };
    try std.testing.expectError(error.OptionsInvalid, client.containers.listFiles("a/b", .{ .limit = 2, .after = "scan/?" }, invalid));
    try std.testing.expectError(error.OptionsInvalid, client.containers.getFile("a/b", "c?d", invalid));
    try std.testing.expectError(error.OptionsInvalid, client.containers.promoteFile("a/b", "c?d", invalid));
    try std.testing.expectError(error.OptionsInvalid, client.vault.listSecrets(.{ .limit = 2, .offset = 3 }, invalid));
    try std.testing.expectError(error.OptionsInvalid, client.vault.putSecret("a/b", .{ .value = "secret", .hosts = &.{"api.example.com"} }, invalid));
    try std.testing.expectError(error.OptionsInvalid, client.vault.deleteSecret("a/b", invalid));
    try std.testing.expectError(error.OptionsInvalid, client.vault.listInternSecrets("a/b", .{}, invalid));
    try std.testing.expectError(error.OptionsInvalid, client.vault.listEffectiveSecrets("a/b", .{}, invalid));
    try std.testing.expectError(error.OptionsInvalid, client.vault.putInternSecret("a/b", "c?d", .{ .value = "secret", .hosts = &.{"api.example.com"} }, invalid));
    try std.testing.expectError(error.OptionsInvalid, client.vault.deleteInternSecret("a/b", "c?d", invalid));
    try std.testing.expectError(error.OptionsInvalid, client.vault.copySecrets("a/b", .{ .names = &.{"github_token"} }, invalid));
    try std.testing.expectError(error.OptionsInvalid, client.interns.list(.{ .status = "running,queued", .starting_after = "opaque/?", .workspace_id = "ws" }, invalid));
    try std.testing.expectError(error.OptionsInvalid, client.interns.create(.{ .name = "assistant", .workspace_id = "ws", .provision = false }, invalid));
    try std.testing.expectError(error.OptionsInvalid, client.interns.get("a/b", invalid));
    try std.testing.expectError(error.OptionsInvalid, client.interns.update("a/b", .{ .model = .clear, .description = .{ .value = "hello" } }, invalid));
    try std.testing.expectError(error.OptionsInvalid, client.interns.delete("a/b", .{}, invalid));
    try std.testing.expectError(error.OptionsInvalid, client.interns.getDaemon("a/b", invalid));
    try std.testing.expectError(error.OptionsInvalid, client.interns.signDaemon("a/b", .{ .bodySha256 = "digest" }, invalid));
    try std.testing.expectError(error.OptionsInvalid, client.interns.invoke("a/b", .{ .input = "hello", .session_id = "session" }, invalid));
    try std.testing.expectError(error.OptionsInvalid, client.interns.provision("a/b", invalid));
    try std.testing.expectError(error.OptionsInvalid, client.interns.suspendIntern("a/b", invalid));
    try std.testing.expectError(error.OptionsInvalid, client.containers.content("c", "f", invalid));
    try std.testing.expectError(error.OptionsInvalid, client.oauth.jwks(invalid));
    try std.testing.expectError(error.OptionsInvalid, client.oauth.exchangeToken(.{ .subject_token = "jwt", .federation_policy_id = "p" }, invalid));
    const decision_request: decisions_mod.Request = .{ .model = "m", .state = .{ .string = "state" }, .questions = .{} };
    try std.testing.expectError(error.OptionsInvalid, client.systemone.create(decision_request, invalid));
    try std.testing.expectError(error.OptionsInvalid, client.alpha.decisions.create(decision_request, invalid));
    try std.testing.expectError(error.OptionsInvalid, client.interns.chat("i", .{ .messages = &.{.{ .role = .user, .content = .{ .text = "hello" } }} }, invalid));
    try std.testing.expectError(error.OptionsInvalid, client.private_endpoints.create(.{ .model_permaslug = "m", .provider_slug = "p", .upstream_model_id = "id" }, invalid));
    try std.testing.expectError(error.OptionsInvalid, client.private_endpoints.update("id", .{ .upstream_model_id = "model" }, invalid));
    try std.testing.expectError(error.OptionsInvalid, client.private_endpoints.delete("id", invalid));
    try std.testing.expectError(error.OptionsInvalid, client.private_endpoints.activate("id", invalid));
    try std.testing.expectError(error.OptionsInvalid, client.private_endpoints.disable("id", invalid));
    try std.testing.expectError(error.OptionsInvalid, client.private_endpoints.enable("id", invalid));
    try std.testing.expectError(error.OptionsInvalid, client.private_endpoints.validate("id", .{ .workspace_id = "ws" }, invalid));
    try std.testing.expectError(error.OptionsInvalid, client.private_endpoints.updatePricing("id", .{ .pricing = .{ .prompt = "0", .completion = "0" } }, invalid));
}
