//! Chat completions API.

const std = @import("std");

const errors = @import("errors.zig");
const config_mod = @import("config.zig");
const http = @import("http.zig");
const json = @import("json.zig");
const options_mod = @import("options.zig");

pub const Role = enum {
    system,
    user,
    assistant,
    tool,
};

pub const Message = struct {
    role: Role,
    content: MessageContent,
    name: ?[]const u8 = null,
    tool_call_id: ?[]const u8 = null,
    tool_calls: ?[]const ToolCall = null,
};

pub const MessageContent = union(enum) {
    text: []const u8,
    parts: []const ContentPart,

    pub fn jsonStringify(self: MessageContent, jws: anytype) !void {
        switch (self) {
            .text => |text| try jws.write(text),
            .parts => |parts| try jws.write(parts),
        }
    }
};

pub const ContentPart = union(enum) {
    text: []const u8,
    image_url: []const u8,

    pub fn jsonStringify(self: ContentPart, jws: anytype) !void {
        try jws.beginObject();
        switch (self) {
            .text => |text| {
                try jws.objectField("type");
                try jws.write("text");
                try jws.objectField("text");
                try jws.write(text);
            },
            .image_url => |url| {
                try jws.objectField("type");
                try jws.write("image_url");
                try jws.objectField("image_url");
                try jws.beginObject();
                try jws.objectField("url");
                try jws.write(url);
                try jws.endObject();
            },
        }
        try jws.endObject();
    }
};

pub const ToolCall = struct {
    id: []const u8,
    name: []const u8,
    arguments: []const u8,
};

pub const CompletionRequest = struct {
    model: []const u8,
    messages: []const Message,
    temperature: ?f32 = null,
    top_p: ?f32 = null,
    max_tokens: ?u32 = null,
    seed: ?i64 = null,
    frequency_penalty: ?f32 = null,
    presence_penalty: ?f32 = null,
    response_format: ?ResponseFormat = null,
    provider: ?ProviderRouting = null,
    stream: bool = false,
    stop: ?[]const []const u8 = null,
    extra_body: ?std.json.Value = null,

    pub fn jsonStringify(self: CompletionRequest, jws: anytype) !void {
        try jws.beginObject();
        try jws.objectField("model");
        try jws.write(self.model);
        try jws.objectField("messages");
        try jws.write(self.messages);
        if (self.temperature) |value| {
            try jws.objectField("temperature");
            try jws.write(value);
        }
        if (self.top_p) |value| {
            try jws.objectField("top_p");
            try jws.write(value);
        }
        if (self.max_tokens) |value| {
            try jws.objectField("max_tokens");
            try jws.write(value);
        }
        if (self.seed) |value| {
            try jws.objectField("seed");
            try jws.write(value);
        }
        if (self.frequency_penalty) |value| {
            try jws.objectField("frequency_penalty");
            try jws.write(value);
        }
        if (self.presence_penalty) |value| {
            try jws.objectField("presence_penalty");
            try jws.write(value);
        }
        if (self.response_format) |value| {
            try jws.objectField("response_format");
            try jws.write(value);
        }
        if (self.provider) |value| {
            try jws.objectField("provider");
            try jws.write(value);
        }
        try jws.objectField("stream");
        try jws.write(self.stream);
        if (self.stop) |value| {
            try jws.objectField("stop");
            try jws.write(value);
        }
        if (self.extra_body) |value| switch (value) {
            .object => |object| {
                var it = object.iterator();
                while (it.next()) |entry| {
                    try jws.objectField(entry.key_ptr.*);
                    try jws.write(entry.value_ptr.*);
                }
            },
            else => {},
        };
        try jws.endObject();
    }
};

pub const ResponseFormat = struct {
    type: []const u8,
};

pub const ProviderRouting = struct {
    order: ?[]const []const u8 = null,
    allow_fallbacks: ?bool = null,
    require_parameters: ?bool = null,
};

pub const CompletionResponse = struct {
    arena: std.heap.ArenaAllocator,
    response_metadata: http.ResponseMetadata = .{},
    id: []const u8,
    model: []const u8,
    choices: []Choice,
    usage: ?Usage = null,

    pub fn deinit(self: *CompletionResponse) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

pub const Choice = struct {
    index: u32 = 0,
    message: AssistantMessage,
    finish_reason: ?[]const u8 = null,
    native_finish_reason: ?[]const u8 = null,
};

pub const AssistantMessage = struct {
    role: Role,
    content: ?[]const u8 = null,
};

pub const Usage = struct {
    prompt_tokens: ?u32 = null,
    completion_tokens: ?u32 = null,
    total_tokens: ?u32 = null,
};

const WireCompletionResponse = struct {
    id: []const u8,
    model: []const u8,
    choices: []Choice,
    usage: ?Usage = null,
};

pub fn create(client: anytype, request: CompletionRequest, request_options: options_mod.RequestOptions) !CompletionResponse {
    return createWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, request, request_options);
}

pub fn createWithTransport(
    allocator: std.mem.Allocator,
    config: config_mod.Config,
    transport: anytype,
    request: CompletionRequest,
    request_options: options_mod.RequestOptions,
) !CompletionResponse {
    const body = try json.stringifyRequest(allocator, forceNonStreaming(request));
    defer allocator.free(body);

    var prepared = try http.prepareRequest(allocator, config, .{
        .method = .POST,
        .path = "/chat/completions",
        .body = body,
    }, request_options);
    defer prepared.deinit();

    var response = try transport.execute(allocator, prepared);
    defer response.deinit();

    return parseCompletionResponse(allocator, response);
}

pub fn parseCompletionResponse(allocator: std.mem.Allocator, response: http.HttpResponse) !CompletionResponse {
    if (errors.isErrorStatus(@intFromEnum(response.status))) return error.ApiError;

    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const arena_allocator = arena.allocator();

    const owned_body = try arena_allocator.dupe(u8, response.body);
    const parsed = try json.parseResponseLeaky(WireCompletionResponse, arena_allocator, owned_body);
    return .{
        .arena = arena,
        .response_metadata = try http.ResponseMetadata.fromHttpResponse(arena_allocator, response),
        .id = parsed.id,
        .model = parsed.model,
        .choices = parsed.choices,
        .usage = parsed.usage,
    };
}

fn forceNonStreaming(request: CompletionRequest) CompletionRequest {
    var copy = request;
    copy.stream = false;
    return copy;
}

test "chat request serializes content string and omits null optionals" {
    const messages = &.{Message{ .role = .user, .content = .{ .text = "Hello" } }};
    const body = try json.stringifyRequest(std.testing.allocator, forceNonStreaming(.{
        .model = "openai/gpt-4o-mini",
        .messages = messages,
    }));
    defer std.testing.allocator.free(body);

    try std.testing.expect(std.mem.indexOf(u8, body, "\"model\":\"openai/gpt-4o-mini\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"role\":\"user\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"content\":\"Hello\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"temperature\"") == null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"stream\":false") != null);
}

test "chat request merges extra body object fields" {
    var extra: std.json.ObjectMap = .empty;
    defer extra.deinit(std.testing.allocator);
    try extra.put(std.testing.allocator, "route", .{ .string = "fallback" });

    const messages = &.{Message{ .role = .user, .content = .{ .text = "Hello" } }};
    const body = try json.stringifyRequest(std.testing.allocator, CompletionRequest{
        .model = "openai/gpt-4o-mini",
        .messages = messages,
        .extra_body = .{ .object = extra },
    });
    defer std.testing.allocator.free(body);

    try std.testing.expect(std.mem.indexOf(u8, body, "\"route\":\"fallback\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"extra_body\"") == null);
}

test "chat request serializes multipart content" {
    const parts = &.{
        ContentPart{ .text = "Describe this" },
        ContentPart{ .image_url = "https://example.com/image.png" },
    };
    const messages = &.{Message{ .role = .user, .content = .{ .parts = parts } }};
    const body = try json.stringifyRequest(std.testing.allocator, CompletionRequest{
        .model = "openai/gpt-4o-mini",
        .messages = messages,
    });
    defer std.testing.allocator.free(body);

    try std.testing.expect(std.mem.indexOf(u8, body, "\"type\":\"text\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"type\":\"image_url\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "https://example.com/image.png") != null);
}

test "chat create parses non-streaming completion" {
    const response_body =
        \\{
        \\  "id": "gen-123",
        \\  "object": "chat.completion",
        \\  "created": 123,
        \\  "model": "openai/gpt-4o-mini",
        \\  "choices": [
        \\    {
        \\      "index": 0,
        \\      "finish_reason": "stop",
        \\      "message": { "role": "assistant", "content": "Hi there" }
        \\    }
        \\  ],
        \\  "usage": { "prompt_tokens": 4, "completion_tokens": 2, "total_tokens": 6 }
        \\}
    ;
    const messages = &.{Message{ .role = .user, .content = .{ .text = "Hello" } }};

    var result = try createWithTransport(std.testing.allocator, .{ .api_key = "test-key" }, http.FakeTransport{
        .body = response_body,
        .headers = &.{
            .{ .name = "x-request-id", .value = "req_chat_123" },
            .{ .name = "x-ratelimit-remaining", .value = "42" },
            .{ .name = "x-ratelimit-reset", .value = "60" },
        },
    }, .{
        .model = "openai/gpt-4o-mini",
        .messages = messages,
    }, .{});
    defer result.deinit();

    try std.testing.expectEqualStrings("gen-123", result.id);
    try std.testing.expectEqualStrings("openai/gpt-4o-mini", result.model);
    try std.testing.expectEqual(@as(usize, 1), result.choices.len);
    try std.testing.expectEqual(Role.assistant, result.choices[0].message.role);
    try std.testing.expectEqualStrings("Hi there", result.choices[0].message.content.?);
    try std.testing.expectEqual(@as(?u32, 6), result.usage.?.total_tokens);
    try std.testing.expectEqualStrings("req_chat_123", result.response_metadata.request_id.?);
    try std.testing.expectEqualStrings("42", result.response_metadata.rate_limit_remaining.?);
    try std.testing.expectEqualStrings("60", result.response_metadata.rate_limit_reset.?);
}

test "chat create maps error status to ApiError" {
    const messages = &.{Message{ .role = .user, .content = .{ .text = "Hello" } }};

    try std.testing.expectError(error.ApiError, createWithTransport(
        std.testing.allocator,
        .{ .api_key = "test-key" },
        http.FakeTransport{ .status = .too_many_requests, .body = "{\"error\":{\"message\":\"rate limited\"}}" },
        .{ .model = "openai/gpt-4o-mini", .messages = messages },
        .{},
    ));
}
