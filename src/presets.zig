//! Preset-based inference API.

const std = @import("std");

const chat_mod = @import("chat.zig");
const config_mod = @import("config.zig");
const errors = @import("errors.zig");
const http = @import("http.zig");
const json = @import("json.zig");
const messages_mod = @import("messages.zig");
const options_mod = @import("options.zig");
const responses_mod = @import("responses.zig");

pub const ChatCompletionsCreateRequest = struct {
    slug: []const u8,
    request: chat_mod.CompletionRequest,
};

pub const MessagesCreateRequest = struct {
    slug: []const u8,
    request: messages_mod.CreateRequest,
};

pub const ResponsesCreateRequest = struct {
    slug: []const u8,
    request: responses_mod.CreateRequest,
};

pub const PresetCreateResponse = struct {
    arena: std.heap.ArenaAllocator,
    response_metadata: http.ResponseMetadata = .{},
    data: Preset,

    pub fn deinit(self: *PresetCreateResponse) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

pub const ChatCompletionsCreateResponse = PresetCreateResponse;
pub const MessagesCreateResponse = PresetCreateResponse;
pub const ResponsesCreateResponse = PresetCreateResponse;

pub const Preset = struct {
    id: []const u8,
    name: ?[]const u8 = null,
    slug: []const u8,
    status: ?[]const u8 = null,
    designated_version_id: ?[]const u8 = null,
    created_at: ?[]const u8 = null,
    updated_at: ?[]const u8 = null,
    designated_version: ?PresetVersion = null,
};

pub const PresetVersion = struct {
    id: []const u8,
    version: ?i64 = null,
    system_prompt: ?[]const u8 = null,
    config: ?std.json.Value = null,
    created_at: ?[]const u8 = null,
    updated_at: ?[]const u8 = null,
};

const WirePresetCreateResponse = struct {
    data: Preset,
};

pub fn createChatCompletion(client: anytype, request: ChatCompletionsCreateRequest, request_options: options_mod.RequestOptions) !ChatCompletionsCreateResponse {
    return createChatCompletionWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, request, request_options);
}

pub fn createMessage(client: anytype, request: MessagesCreateRequest, request_options: options_mod.RequestOptions) !MessagesCreateResponse {
    return createMessageWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, request, request_options);
}

pub fn createResponse(client: anytype, request: ResponsesCreateRequest, request_options: options_mod.RequestOptions) !ResponsesCreateResponse {
    return createResponseWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, request, request_options);
}

pub fn createChatCompletionWithTransport(
    allocator: std.mem.Allocator,
    config: config_mod.Config,
    transport: anytype,
    request: ChatCompletionsCreateRequest,
    request_options: options_mod.RequestOptions,
) !ChatCompletionsCreateResponse {
    const body = try json.stringifyRequest(allocator, forceNonStreaming(request.request));
    defer allocator.free(body);
    const path = try chatCompletionsPath(allocator, request.slug);
    defer allocator.free(path);

    var prepared = try http.prepareRequest(allocator, config, .{
        .method = .POST,
        .path = path,
        .body = body,
    }, request_options);
    defer prepared.deinit();

    var response = try transport.execute(allocator, prepared);
    defer response.deinit();

    return parsePresetCreateResponse(allocator, response);
}

pub fn parseChatCompletionsCreateResponse(allocator: std.mem.Allocator, response: http.HttpResponse) !ChatCompletionsCreateResponse {
    return parsePresetCreateResponse(allocator, response);
}

pub fn parsePresetCreateResponse(allocator: std.mem.Allocator, response: http.HttpResponse) !PresetCreateResponse {
    if (errors.isErrorStatus(@intFromEnum(response.status))) return error.ApiError;

    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const arena_allocator = arena.allocator();

    const owned_body = try arena_allocator.dupe(u8, response.body);
    const parsed = try json.parseResponseLeaky(WirePresetCreateResponse, arena_allocator, owned_body);
    return .{
        .arena = arena,
        .response_metadata = try http.ResponseMetadata.fromHttpResponse(arena_allocator, response),
        .data = parsed.data,
    };
}

pub fn createMessageWithTransport(
    allocator: std.mem.Allocator,
    config: config_mod.Config,
    transport: anytype,
    request: MessagesCreateRequest,
    request_options: options_mod.RequestOptions,
) !MessagesCreateResponse {
    const body = try json.stringifyRequest(allocator, request.request);
    defer allocator.free(body);
    const path = try messagesPath(allocator, request.slug);
    defer allocator.free(path);

    var prepared = try http.prepareRequest(allocator, config, .{
        .method = .POST,
        .path = path,
        .body = body,
    }, request_options);
    defer prepared.deinit();

    var response = try transport.execute(allocator, prepared);
    defer response.deinit();

    return parsePresetCreateResponse(allocator, response);
}

pub fn createResponseWithTransport(
    allocator: std.mem.Allocator,
    config: config_mod.Config,
    transport: anytype,
    request: ResponsesCreateRequest,
    request_options: options_mod.RequestOptions,
) !ResponsesCreateResponse {
    const body = try json.stringifyRequest(allocator, request.request);
    defer allocator.free(body);
    const path = try responsesPath(allocator, request.slug);
    defer allocator.free(path);

    var prepared = try http.prepareRequest(allocator, config, .{
        .method = .POST,
        .path = path,
        .body = body,
    }, request_options);
    defer prepared.deinit();

    var response = try transport.execute(allocator, prepared);
    defer response.deinit();

    return parsePresetCreateResponse(allocator, response);
}

fn forceNonStreaming(request: chat_mod.CompletionRequest) chat_mod.CompletionRequest {
    var copy = request;
    copy.stream = false;
    return copy;
}

fn chatCompletionsPath(allocator: std.mem.Allocator, slug: []const u8) ![]u8 {
    var path: std.ArrayList(u8) = .empty;
    errdefer path.deinit(allocator);

    try path.appendSlice(allocator, "/presets/");
    try appendPathSegment(allocator, &path, slug);
    try path.appendSlice(allocator, "/chat/completions");

    return path.toOwnedSlice(allocator);
}

fn messagesPath(allocator: std.mem.Allocator, slug: []const u8) ![]u8 {
    return presetEndpointPath(allocator, slug, "/messages");
}

fn responsesPath(allocator: std.mem.Allocator, slug: []const u8) ![]u8 {
    return presetEndpointPath(allocator, slug, "/responses");
}

fn presetEndpointPath(allocator: std.mem.Allocator, slug: []const u8, suffix: []const u8) ![]u8 {
    var path: std.ArrayList(u8) = .empty;
    errdefer path.deinit(allocator);

    try path.appendSlice(allocator, "/presets/");
    try appendPathSegment(allocator, &path, slug);
    try path.appendSlice(allocator, suffix);

    return path.toOwnedSlice(allocator);
}

fn appendPathSegment(allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: []const u8) !void {
    const hex = "0123456789ABCDEF";
    for (value) |byte| {
        if (std.ascii.isAlphanumeric(byte) or byte == '-' or byte == '_' or byte == '.' or byte == '~') {
            try output.append(allocator, byte);
        } else {
            try output.appendSlice(allocator, &.{ '%', hex[byte >> 4], hex[byte & 0x0F] });
        }
    }
}

test "preset chat completions create serializes chat request" {
    const body = try json.stringifyRequest(std.testing.allocator, forceNonStreaming(.{
        .model = "openai/gpt-4o-mini",
        .messages = &.{.{ .role = .user, .content = .{ .text = "Write a marketing email." } }},
        .temperature = 0.7,
        .stream = true,
    }));
    defer std.testing.allocator.free(body);

    try std.testing.expect(std.mem.indexOf(u8, body, "\"model\":\"openai/gpt-4o-mini\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"content\":\"Write a marketing email.\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"stream\":false") != null);
}

test "preset chat completions create parses response" {
    const body =
        \\{
        \\  "data": {
        \\    "id": "preset_123",
        \\    "name": "Email Copywriter",
        \\    "slug": "email-copywriter",
        \\    "status": "active",
        \\    "designated_version_id": "version_123",
        \\    "created_at": "2026-04-20T10:00:00Z",
        \\    "updated_at": "2026-04-20T10:00:00Z",
        \\    "designated_version": {
        \\      "id": "version_123",
        \\      "version": 1,
        \\      "system_prompt": "You are a helpful assistant.",
        \\      "config": { "model": "openai/gpt-4o-mini", "temperature": 0.7 },
        \\      "created_at": "2026-04-20T10:00:00Z",
        \\      "updated_at": "2026-04-20T10:00:00Z"
        \\    },
        \\    "unknown": true
        \\  }
        \\}
    ;

    var result = try createChatCompletionWithTransport(std.testing.allocator, .{ .api_key = "test-key" }, http.FakeTransport{ .body = body }, .{
        .slug = "email-copywriter",
        .request = .{
            .model = "openai/gpt-4o-mini",
            .messages = &.{.{ .role = .user, .content = .{ .text = "Write a marketing email." } }},
        },
    }, .{});
    defer result.deinit();

    try std.testing.expectEqualStrings("preset_123", result.data.id);
    try std.testing.expectEqualStrings("email-copywriter", result.data.slug);
    try std.testing.expectEqualStrings("version_123", result.data.designated_version.?.id);
    try std.testing.expectEqual(@as(?i64, 1), result.data.designated_version.?.version);
}

test "preset chat completions create sends POST /presets/{slug}/chat/completions" {
    const path = try chatCompletionsPath(std.testing.allocator, "email copywriter");
    defer std.testing.allocator.free(path);

    var prepared = try http.prepareRequest(std.testing.allocator, .{ .api_key = "test-key" }, .{
        .method = .POST,
        .path = path,
        .body = "{}",
    }, .{});
    defer prepared.deinit();

    try std.testing.expectEqual(std.http.Method.POST, prepared.method);
    try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/presets/email%20copywriter/chat/completions", prepared.url);
}

test "preset chat completions create maps error status to ApiError" {
    try std.testing.expectError(error.ApiError, createChatCompletionWithTransport(
        std.testing.allocator,
        .{ .api_key = "test-key" },
        http.FakeTransport{ .status = .bad_request, .body = "{\"error\":{\"message\":\"bad preset\"}}" },
        .{
            .slug = "email-copywriter",
            .request = .{
                .model = "openai/gpt-4o-mini",
                .messages = &.{.{ .role = .user, .content = .{ .text = "Hello" } }},
            },
        },
        .{},
    ));
}

test "preset messages create serializes messages request" {
    const body = try json.stringifyRequest(std.testing.allocator, (MessagesCreateRequest{
        .slug = "anthropic-preset",
        .request = .{
            .model = "anthropic/claude-3.5-sonnet",
            .messages = &.{.{ .role = .user, .content = .{ .text = "Write a haiku." } }},
            .max_tokens = 128,
        },
    }).request);
    defer std.testing.allocator.free(body);

    try std.testing.expect(std.mem.indexOf(u8, body, "\"model\":\"anthropic/claude-3.5-sonnet\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"content\":\"Write a haiku.\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"max_tokens\":128") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"slug\"") == null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"stream\"") == null);
}

test "preset messages create parses response" {
    const body =
        \\{
        \\  "data": {
        \\    "id": "preset_msg_123",
        \\    "name": "Anthropic Preset",
        \\    "slug": "anthropic-preset",
        \\    "status": "active",
        \\    "designated_version_id": "version_msg_123",
        \\    "designated_version": {
        \\      "id": "version_msg_123",
        \\      "version": 2,
        \\      "system_prompt": "You are concise."
        \\    }
        \\  }
        \\}
    ;

    var result = try createMessageWithTransport(std.testing.allocator, .{ .api_key = "test-key" }, http.FakeTransport{ .body = body }, .{
        .slug = "anthropic-preset",
        .request = .{
            .model = "anthropic/claude-3.5-sonnet",
            .messages = &.{.{ .role = .user, .content = .{ .text = "Hello" } }},
        },
    }, .{});
    defer result.deinit();

    try std.testing.expectEqualStrings("preset_msg_123", result.data.id);
    try std.testing.expectEqualStrings("anthropic-preset", result.data.slug);
    try std.testing.expectEqualStrings("version_msg_123", result.data.designated_version.?.id);
}

test "preset messages create sends POST /presets/{slug}/messages" {
    const path = try messagesPath(std.testing.allocator, "anthropic preset");
    defer std.testing.allocator.free(path);

    var prepared = try http.prepareRequest(std.testing.allocator, .{ .api_key = "test-key" }, .{
        .method = .POST,
        .path = path,
        .body = "{}",
    }, .{});
    defer prepared.deinit();

    try std.testing.expectEqual(std.http.Method.POST, prepared.method);
    try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/presets/anthropic%20preset/messages", prepared.url);
}

test "preset messages create maps error status to ApiError" {
    try std.testing.expectError(error.ApiError, createMessageWithTransport(
        std.testing.allocator,
        .{ .api_key = "test-key" },
        http.FakeTransport{ .status = .bad_request, .body = "{\"error\":{\"message\":\"bad preset\"}}" },
        .{
            .slug = "anthropic-preset",
            .request = .{
                .model = "anthropic/claude-3.5-sonnet",
                .messages = &.{.{ .role = .user, .content = .{ .text = "Hello" } }},
            },
        },
        .{},
    ));
}

test "preset responses create serializes responses request" {
    const body = try json.stringifyRequest(std.testing.allocator, (ResponsesCreateRequest{
        .slug = "openai-preset",
        .request = .{
            .model = "openai/o4-mini",
            .input = .{ .text = "Summarize this." },
            .max_output_tokens = 256,
        },
    }).request);
    defer std.testing.allocator.free(body);

    try std.testing.expect(std.mem.indexOf(u8, body, "\"model\":\"openai/o4-mini\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"input\":\"Summarize this.\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"max_output_tokens\":256") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"slug\"") == null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"stream\"") == null);
}

test "preset responses create parses response" {
    const body =
        \\{
        \\  "data": {
        \\    "id": "preset_resp_123",
        \\    "name": "OpenAI Preset",
        \\    "slug": "openai-preset",
        \\    "status": "active",
        \\    "designated_version_id": "version_resp_123",
        \\    "designated_version": {
        \\      "id": "version_resp_123",
        \\      "version": 3,
        \\      "system_prompt": "You are precise."
        \\    }
        \\  }
        \\}
    ;

    var result = try createResponseWithTransport(std.testing.allocator, .{ .api_key = "test-key" }, http.FakeTransport{ .body = body }, .{
        .slug = "openai-preset",
        .request = .{
            .model = "openai/o4-mini",
            .input = .{ .text = "Hello" },
        },
    }, .{});
    defer result.deinit();

    try std.testing.expectEqualStrings("preset_resp_123", result.data.id);
    try std.testing.expectEqualStrings("openai-preset", result.data.slug);
    try std.testing.expectEqualStrings("version_resp_123", result.data.designated_version.?.id);
}

test "preset responses create sends POST /presets/{slug}/responses" {
    const path = try responsesPath(std.testing.allocator, "openai preset");
    defer std.testing.allocator.free(path);

    var prepared = try http.prepareRequest(std.testing.allocator, .{ .api_key = "test-key" }, .{
        .method = .POST,
        .path = path,
        .body = "{}",
    }, .{});
    defer prepared.deinit();

    try std.testing.expectEqual(std.http.Method.POST, prepared.method);
    try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/presets/openai%20preset/responses", prepared.url);
}

test "preset responses create maps error status to ApiError" {
    try std.testing.expectError(error.ApiError, createResponseWithTransport(
        std.testing.allocator,
        .{ .api_key = "test-key" },
        http.FakeTransport{ .status = .bad_request, .body = "{\"error\":{\"message\":\"bad preset\"}}" },
        .{
            .slug = "openai-preset",
            .request = .{
                .model = "openai/o4-mini",
                .input = .{ .text = "Hello" },
            },
        },
        .{},
    ));
}
