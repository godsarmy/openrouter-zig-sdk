//! Root OpenRouter client.

const std = @import("std");
const activity_mod = @import("activity.zig");
const analytics_mod = @import("analytics.zig");
const audio_mod = @import("audio.zig");
const byok_mod = @import("byok.zig");
const chat_mod = @import("chat.zig");
const config_mod = @import("config.zig");
const credits_mod = @import("credits.zig");
const auth_keys_mod = @import("auth_keys.zig");
const datasets_mod = @import("datasets.zig");
const embeddings_mod = @import("embeddings.zig");
const endpoints_mod = @import("endpoints.zig");
const files_mod = @import("files.zig");
const generation_mod = @import("generation.zig");
const guardrails_mod = @import("guardrails.zig");
const key_mod = @import("key.zig");
const keys_mod = @import("keys.zig");
const messages_mod = @import("messages.zig");
const models_mod = @import("models.zig");
const observability_mod = @import("observability.zig");
const options_mod = @import("options.zig");
const organization_mod = @import("organization.zig");
const presets_mod = @import("presets.zig");
const providers_mod = @import("providers.zig");
const rerank_mod = @import("rerank.zig");
const responses_mod = @import("responses.zig");
const stream_mod = @import("stream.zig");
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
pub const WorkspaceBudgetsResource = struct {
    pub fn list(self: *WorkspaceBudgetsResource, id: []const u8, request_options: options_mod.RequestOptions) !workspaces_mod.BudgetListResponse {
        const workspaces: *WorkspacesResource = @alignCast(@fieldParentPtr("budgets", self));
        const client: *Client = @alignCast(@fieldParentPtr("workspaces", workspaces));
        return workspaces_mod.listBudgets(client, id, request_options);
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
pub const OrganizationResource = struct {
    members: OrganizationMembersResource = .{},
};
pub const OrganizationMembersResource = struct {
    pub fn list(self: *OrganizationMembersResource, request: organization_mod.MembersListRequest, request_options: options_mod.RequestOptions) !organization_mod.MembersListResponse {
        const organization: *OrganizationResource = @alignCast(@fieldParentPtr("members", self));
        const client: *Client = @alignCast(@fieldParentPtr("organization", organization));
        return organization_mod.listMembers(client, request, request_options);
    }
};
pub const OAuthResource = struct {
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
    audio: AudioResource,
    models: ModelsResource,
    embeddings: EmbeddingsResource,
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
    oauth: OAuthResource,
    key: KeyResource,
    keys: KeysResource,
    providers: ProvidersResource,
    generation: GenerationResource,
    activity: ActivityResource,
    analytics: AnalyticsResource,
    datasets: DatasetsResource,

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
            .oauth = .{},
            .key = .{},
            .keys = .{},
            .providers = .{},
            .generation = .{},
            .activity = .{},
            .analytics = .{},
            .datasets = .{},
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
    _ = client.organization;
    _ = client.organization.members;
    _ = client.key;
    _ = client.keys;
    _ = client.providers;
    _ = client.generation;
    _ = client.activity;
    _ = client.analytics;
    _ = client.analytics.meta;
    _ = client.datasets;
    _ = client.datasets.app_rankings;
    _ = client.datasets.benchmarks;
    _ = client.datasets.benchmarks.artificial_analysis;
    _ = client.datasets.benchmarks.design_arena;
    _ = client.datasets.rankings_daily;
}
