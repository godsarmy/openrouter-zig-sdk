//! Anthropic-compatible Messages API.

const std = @import("std");

const config_mod = @import("config.zig");
const errors = @import("errors.zig");
const http = @import("http.zig");
const json = @import("json.zig");
const options_mod = @import("options.zig");

pub const CreateRequest = struct {
    model: []const u8,
    messages: []const Message,
    max_tokens: ?u32 = null,
    system: ?Content = null,
    temperature: ?f32 = null,
    top_p: ?f32 = null,
    top_k: ?u32 = null,
    stop_sequences: ?[]const []const u8 = null,
    metadata: ?std.json.Value = null,
    user: ?[]const u8 = null,
    trace: ?std.json.Value = null,
    session_id: ?[]const u8 = null,
    speed: ?f32 = null,
    models: ?[]const []const u8 = null,
    output_config: ?std.json.Value = null,
    plugins: ?[]const std.json.Value = null,
    context_management: ?std.json.Value = null,
    cache_control: ?std.json.Value = null,
    stop_server_tools_when: ?std.json.Value = null,
    tools: ?[]const std.json.Value = null,
    tool_choice: ?std.json.Value = null,
    thinking: ?std.json.Value = null,
    service_tier: ?[]const u8 = null,
    provider: ?std.json.Value = null,
    extra_body: ?std.json.Value = null,

    pub fn jsonStringify(self: CreateRequest, jws: anytype) !void {
        try jws.beginObject();
        try jws.objectField("model");
        try jws.write(self.model);
        try jws.objectField("messages");
        try jws.write(self.messages);
        if (self.max_tokens) |value| {
            try jws.objectField("max_tokens");
            try jws.write(value);
        }
        if (self.system) |value| {
            try jws.objectField("system");
            try jws.write(value);
        }
        if (self.temperature) |value| {
            try jws.objectField("temperature");
            try jws.write(value);
        }
        if (self.top_p) |value| {
            try jws.objectField("top_p");
            try jws.write(value);
        }
        if (self.top_k) |value| {
            try jws.objectField("top_k");
            try jws.write(value);
        }
        if (self.stop_sequences) |value| {
            try jws.objectField("stop_sequences");
            try jws.write(value);
        }
        if (self.metadata) |value| {
            try jws.objectField("metadata");
            try jws.write(value);
        }
        if (self.user) |value| {
            try jws.objectField("user");
            try jws.write(value);
        }
        if (self.trace) |value| {
            try jws.objectField("trace");
            try jws.write(value);
        }
        if (self.session_id) |value| {
            try jws.objectField("session_id");
            try jws.write(value);
        }
        if (self.speed) |value| {
            try jws.objectField("speed");
            try jws.write(value);
        }
        if (self.models) |value| {
            try jws.objectField("models");
            try jws.write(value);
        }
        if (self.output_config) |value| {
            try jws.objectField("output_config");
            try jws.write(value);
        }
        if (self.plugins) |value| {
            try jws.objectField("plugins");
            try jws.write(value);
        }
        if (self.context_management) |value| {
            try jws.objectField("context_management");
            try jws.write(value);
        }
        if (self.cache_control) |value| {
            try jws.objectField("cache_control");
            try jws.write(value);
        }
        if (self.stop_server_tools_when) |value| {
            try jws.objectField("stop_server_tools_when");
            try jws.write(value);
        }
        if (self.tools) |value| {
            try jws.objectField("tools");
            try jws.write(value);
        }
        if (self.tool_choice) |value| {
            try jws.objectField("tool_choice");
            try jws.write(value);
        }
        if (self.thinking) |value| {
            try jws.objectField("thinking");
            try jws.write(value);
        }
        if (self.service_tier) |value| {
            try jws.objectField("service_tier");
            try jws.write(value);
        }
        if (self.provider) |value| {
            try jws.objectField("provider");
            try jws.write(value);
        }
        if (self.extra_body) |value| switch (value) {
            .object => |object| {
                var it = object.iterator();
                while (it.next()) |entry| {
                    if (std.mem.eql(u8, entry.key_ptr.*, "stream")) continue;
                    try jws.objectField(entry.key_ptr.*);
                    try jws.write(entry.value_ptr.*);
                }
            },
            else => {},
        };
        try jws.endObject();
    }
};

pub const Message = struct {
    role: Role,
    content: Content,
};

pub const Role = enum {
    user,
    assistant,
    system,
};

pub const Content = union(enum) {
    text: []const u8,
    blocks: []const std.json.Value,
    value: std.json.Value,

    pub fn jsonStringify(self: Content, jws: anytype) !void {
        switch (self) {
            .text => |value| try jws.write(value),
            .blocks => |value| try jws.write(value),
            .value => |value| try jws.write(value),
        }
    }
};

pub const CreateResponse = struct {
    arena: std.heap.ArenaAllocator,
    id: ?[]const u8 = null,
    type: ?[]const u8 = null,
    role: ?Role = null,
    model: ?[]const u8 = null,
    content: ?[]std.json.Value = null,
    stop_reason: ?[]const u8 = null,
    stop_sequence: ?[]const u8 = null,
    stop_details: ?std.json.Value = null,
    container: ?Container = null,
    usage: ?Usage = null,
    openrouter_metadata: ?std.json.Value = null,

    pub fn deinit(self: *CreateResponse) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

pub const Container = struct {
    id: ?[]const u8 = null,
    expires_at: ?[]const u8 = null,
};

pub const Usage = struct {
    input_tokens: ?u32 = null,
    output_tokens: ?u32 = null,
    cache_creation_input_tokens: ?u32 = null,
    cache_read_input_tokens: ?u32 = null,
    output_tokens_details: ?std.json.Value = null,
    server_tool_use: ?std.json.Value = null,
    service_tier: ?[]const u8 = null,
};

const WireCreateResponse = struct {
    id: ?[]const u8 = null,
    type: ?[]const u8 = null,
    role: ?Role = null,
    model: ?[]const u8 = null,
    content: ?[]std.json.Value = null,
    stop_reason: ?[]const u8 = null,
    stop_sequence: ?[]const u8 = null,
    stop_details: ?std.json.Value = null,
    container: ?Container = null,
    usage: ?Usage = null,
    openrouter_metadata: ?std.json.Value = null,
};

pub fn create(client: anytype, request: CreateRequest, request_options: options_mod.RequestOptions) !CreateResponse {
    return createWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, request, request_options);
}

pub fn createWithTransport(
    allocator: std.mem.Allocator,
    config: config_mod.Config,
    transport: anytype,
    request: CreateRequest,
    request_options: options_mod.RequestOptions,
) !CreateResponse {
    const body = try json.stringifyRequest(allocator, request);
    defer allocator.free(body);

    var prepared = try http.prepareRequest(allocator, config, .{
        .method = .POST,
        .path = "/messages",
        .body = body,
    }, request_options);
    defer prepared.deinit();

    var response = try transport.execute(allocator, prepared);
    defer response.deinit();

    return parseCreateResponse(allocator, response);
}

pub fn parseCreateResponse(allocator: std.mem.Allocator, response: http.HttpResponse) !CreateResponse {
    if (errors.isErrorStatus(@intFromEnum(response.status))) return error.ApiError;

    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const arena_allocator = arena.allocator();

    const owned_body = try arena_allocator.dupe(u8, response.body);
    const parsed = try json.parseResponseLeaky(WireCreateResponse, arena_allocator, owned_body);
    return .{
        .arena = arena,
        .id = parsed.id,
        .type = parsed.type,
        .role = parsed.role,
        .model = parsed.model,
        .content = parsed.content,
        .stop_reason = parsed.stop_reason,
        .stop_sequence = parsed.stop_sequence,
        .stop_details = parsed.stop_details,
        .container = parsed.container,
        .usage = parsed.usage,
        .openrouter_metadata = parsed.openrouter_metadata,
    };
}

test "messages create serializes text request" {
    const messages = &.{Message{ .role = .user, .content = .{ .text = "Hello" } }};
    const body = try json.stringifyRequest(std.testing.allocator, CreateRequest{
        .model = "anthropic/claude-sonnet-4",
        .messages = messages,
        .max_tokens = 128,
        .system = .{ .text = "Be concise." },
    });
    defer std.testing.allocator.free(body);

    try std.testing.expect(std.mem.indexOf(u8, body, "\"model\":\"anthropic/claude-sonnet-4\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"role\":\"user\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"content\":\"Hello\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"max_tokens\":128") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"system\":\"Be concise.\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"stream\"") == null);
}

test "messages create merges extra body" {
    var object: std.json.ObjectMap = .empty;
    defer object.deinit(std.testing.allocator);
    try object.put(std.testing.allocator, "context_management", .{ .bool = true });

    const messages = &.{Message{ .role = .user, .content = .{ .text = "Hello" } }};
    const body = try json.stringifyRequest(std.testing.allocator, CreateRequest{
        .model = "anthropic/claude-sonnet-4",
        .messages = messages,
        .extra_body = .{ .object = object },
    });
    defer std.testing.allocator.free(body);

    try std.testing.expect(std.mem.indexOf(u8, body, "\"context_management\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"extra_body\"") == null);
}

test "messages create ignores stream from extra body" {
    var object: std.json.ObjectMap = .empty;
    defer object.deinit(std.testing.allocator);
    try object.put(std.testing.allocator, "stream", .{ .bool = true });

    const messages = &.{Message{ .role = .user, .content = .{ .text = "Hello" } }};
    const body = try json.stringifyRequest(std.testing.allocator, CreateRequest{
        .model = "anthropic/claude-sonnet-4",
        .messages = messages,
        .extra_body = .{ .object = object },
    });
    defer std.testing.allocator.free(body);

    try std.testing.expect(std.mem.indexOf(u8, body, "\"stream\"") == null);
}

test "messages create parses response and ignores unknown fields" {
    const body =
        \\{
        \\  "container": { "id": "ctr_123", "expires_at": "2026-04-08T00:00:00Z" },
        \\  "content": [{ "type": "text", "text": "Hello" }],
        \\  "id": "msg_123",
        \\  "model": "anthropic/claude-sonnet-4",
        \\  "role": "assistant",
        \\  "stop_reason": "end_turn",
        \\  "type": "message",
        \\  "usage": { "input_tokens": 5, "output_tokens": 7, "service_tier": "standard" },
        \\  "unknown": true
        \\}
    ;

    var result = try createWithTransport(std.testing.allocator, config_mod.Config{ .api_key = "test-key" }, http.FakeTransport{ .body = body }, .{
        .model = "anthropic/claude-sonnet-4",
        .messages = &.{Message{ .role = .user, .content = .{ .text = "Hello" } }},
    }, .{});
    defer result.deinit();

    try std.testing.expectEqualStrings("msg_123", result.id.?);
    try std.testing.expectEqual(Role.assistant, result.role.?);
    try std.testing.expectEqualStrings("message", result.type.?);
    try std.testing.expectEqual(@as(usize, 1), result.content.?.len);
    try std.testing.expectEqualStrings("ctr_123", result.container.?.id.?);
    try std.testing.expectEqual(@as(?u32, 7), result.usage.?.output_tokens);
}

test "messages create sends POST /messages" {
    const body = try json.stringifyRequest(std.testing.allocator, CreateRequest{
        .model = "anthropic/claude-sonnet-4",
        .messages = &.{Message{ .role = .user, .content = .{ .text = "Hello" } }},
    });
    defer std.testing.allocator.free(body);

    var prepared = try http.prepareRequest(std.testing.allocator, .{ .api_key = "test-key" }, .{
        .method = .POST,
        .path = "/messages",
        .body = body,
    }, .{});
    defer prepared.deinit();

    try std.testing.expectEqual(std.http.Method.POST, prepared.method);
    try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/messages", prepared.url);
    try std.testing.expectEqualStrings(body, prepared.body.?);
}

test "messages create maps error status to ApiError" {
    try std.testing.expectError(error.ApiError, createWithTransport(
        std.testing.allocator,
        config_mod.Config{ .api_key = "test-key" },
        http.FakeTransport{ .status = .bad_request, .body = "{\"error\":{\"message\":\"bad request\"}}" },
        .{ .model = "anthropic/claude-sonnet-4", .messages = &.{Message{ .role = .user, .content = .{ .text = "Hello" } }} },
        .{},
    ));
}
