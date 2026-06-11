//! Anthropic-compatible Messages API.

const std = @import("std");

const config_mod = @import("config.zig");
const errors = @import("errors.zig");
const http = @import("http.zig");
const json = @import("json.zig");
const options_mod = @import("options.zig");

const max_line_len = 64 * 1024;
const max_event_len = 1024 * 1024;

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
        try writeCreateRequest(self, jws, false);
    }
};

const StreamingCreateRequest = struct {
    request: CreateRequest,

    pub fn jsonStringify(self: StreamingCreateRequest, jws: anytype) !void {
        try writeCreateRequest(self.request, jws, true);
    }
};

fn writeCreateRequest(self: CreateRequest, jws: anytype, streaming: bool) !void {
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
    if (streaming) {
        try jws.objectField("stream");
        try jws.write(true);
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

pub const MessageStream = struct {
    state: *StreamState,

    pub fn next(self: *MessageStream) !?MessageStreamEvent {
        if (self.state.done) return null;

        const data = try self.state.nextDataEvent() orelse return null;
        defer self.state.allocator.free(data);

        return try parseStreamEvent(self.state.allocator, data);
    }

    pub fn deinit(self: *MessageStream) void {
        self.state.deinit();
        self.* = undefined;
    }
};

pub const MessageStreamEvent = struct {
    arena: std.heap.ArenaAllocator,
    type: ?[]const u8 = null,
    index: ?u32 = null,
    message: ?StreamMessage = null,
    content_block: ?std.json.Value = null,
    delta: ?std.json.Value = null,
    usage: ?Usage = null,
    error_value: ?std.json.Value = null,
    openrouter_metadata: ?std.json.Value = null,

    pub fn textDelta(self: MessageStreamEvent) ?[]const u8 {
        const delta_value = self.delta orelse return null;
        if (delta_value != .object) return null;
        const object = delta_value.object;
        const delta_type = object.get("type") orelse return null;
        if (delta_type != .string or !std.mem.eql(u8, delta_type.string, "text_delta")) return null;
        const text = object.get("text") orelse return null;
        if (text != .string) return null;
        return text.string;
    }

    pub fn deinit(self: *MessageStreamEvent) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

pub const StreamMessage = struct {
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

pub fn stream(client: anytype, request: CreateRequest, request_options: options_mod.RequestOptions) !MessageStream {
    return streamWithHttpClient(client.allocator, &client.http_client, client.config, request, request_options);
}

pub fn streamWithHttpClient(
    allocator: std.mem.Allocator,
    client: *std.http.Client,
    config: config_mod.Config,
    request: CreateRequest,
    request_options: options_mod.RequestOptions,
) !MessageStream {
    const body = try json.stringifyRequest(allocator, StreamingCreateRequest{ .request = request });
    errdefer allocator.free(body);

    var prepared = try http.prepareRequest(allocator, config, .{
        .method = .POST,
        .path = "/messages",
        .body = body,
        .accept = "text/event-stream",
    }, request_options);
    errdefer prepared.deinit();

    const std_headers = try allocator.alloc(std.http.Header, prepared.headers.len);
    errdefer allocator.free(std_headers);
    for (prepared.headers, std_headers) |header, *std_header| {
        std_header.* = .{ .name = header.name, .value = header.value };
    }

    const uri = try std.Uri.parse(prepared.url);
    var req = try client.request(prepared.method, uri, .{
        .extra_headers = std_headers,
        .redirect_behavior = .unhandled,
    });
    errdefer req.deinit();

    try req.sendBodyComplete(body);

    const response = try req.receiveHead(&.{});
    if (errors.isErrorStatus(@intFromEnum(response.head.status))) return error.ApiError;

    const state = try allocator.create(StreamState);
    state.* = .{
        .allocator = allocator,
        .body = body,
        .prepared = prepared,
        .std_headers = std_headers,
        .request = req,
        .response = response,
        .reader = undefined,
    };
    state.reader = state.response.reader(&state.transfer_buffer);

    return .{ .state = state };
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

pub fn parseStreamEvent(allocator: std.mem.Allocator, payload: []const u8) !MessageStreamEvent {
    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const arena_allocator = arena.allocator();

    const owned_payload = try arena_allocator.dupe(u8, payload);
    const parsed = try json.parseResponseLeaky(WireMessageStreamEvent, arena_allocator, owned_payload);
    return .{
        .arena = arena,
        .type = parsed.type,
        .index = parsed.index,
        .message = if (parsed.message) |message| .{
            .id = message.id,
            .type = message.type,
            .role = message.role,
            .model = message.model,
            .content = message.content,
            .stop_reason = message.stop_reason,
            .stop_sequence = message.stop_sequence,
            .stop_details = message.stop_details,
            .container = message.container,
            .usage = message.usage,
            .openrouter_metadata = message.openrouter_metadata,
        } else null,
        .content_block = parsed.content_block,
        .delta = parsed.delta,
        .usage = parsed.usage,
        .error_value = @field(parsed, "error"),
        .openrouter_metadata = parsed.openrouter_metadata,
    };
}

const WireMessageStreamEvent = struct {
    type: ?[]const u8 = null,
    index: ?u32 = null,
    message: ?WireCreateResponse = null,
    content_block: ?std.json.Value = null,
    delta: ?std.json.Value = null,
    usage: ?Usage = null,
    @"error": ?std.json.Value = null,
    openrouter_metadata: ?std.json.Value = null,
};

const StreamState = struct {
    allocator: std.mem.Allocator,
    body: []u8,
    prepared: http.PreparedRequest,
    std_headers: []std.http.Header,
    request: std.http.Client.Request,
    response: std.http.Client.Response,
    reader: *std.Io.Reader,
    transfer_buffer: [8192]u8 = undefined,
    read_buffer: [4096]u8 = undefined,
    read_pos: usize = 0,
    read_end: usize = 0,
    done: bool = false,

    fn deinit(self: *StreamState) void {
        self.request.deinit();
        self.allocator.free(self.std_headers);
        self.prepared.deinit();
        self.allocator.free(self.body);
        const allocator = self.allocator;
        self.* = undefined;
        allocator.destroy(self);
    }

    fn nextDataEvent(self: *StreamState) !?[]u8 {
        if (self.done) return null;

        while (true) {
            var event_data: std.Io.Writer.Allocating = .init(self.allocator);
            defer event_data.deinit();
            var saw_data = false;

            while (true) {
                const maybe_line = try self.readLineAlloc();
                const line = maybe_line orelse {
                    self.done = true;
                    if (saw_data) return error.UnexpectedEndOfStream;
                    return null;
                };
                defer self.allocator.free(line);

                if (line.len == 0) break;
                if (line[0] == ':') continue;
                if (dataLineValue(line)) |value| {
                    if (saw_data) try event_data.writer.writeByte('\n');
                    try event_data.writer.writeAll(value);
                    if (event_data.written().len > max_event_len) return error.StreamTooLong;
                    saw_data = true;
                } else {
                    if (std.mem.indexOfScalar(u8, line, ':') == null) return error.MalformedSse;
                    continue;
                }
            }

            if (!saw_data) continue;
            if (std.mem.eql(u8, event_data.written(), "[DONE]")) {
                self.done = true;
                return null;
            }
            return try event_data.toOwnedSlice();
        }
    }

    fn readLineAlloc(self: *StreamState) !?[]u8 {
        var line: std.Io.Writer.Allocating = .init(self.allocator);
        defer line.deinit();

        while (true) {
            const byte = try self.readByte() orelse {
                if (line.written().len == 0) return null;
                return try trimCarriageReturnOwned(&line);
            };
            if (byte == '\n') return try trimCarriageReturnOwned(&line);
            try line.writer.writeByte(byte);
            if (line.written().len > max_line_len) return error.StreamTooLong;
        }
    }

    fn readByte(self: *StreamState) !?u8 {
        if (self.read_pos >= self.read_end) {
            const n = self.reader.readSliceShort(&self.read_buffer) catch |err| switch (err) {
                error.ReadFailed => return error.UnexpectedEndOfStream,
            };
            if (n == 0) return null;
            self.read_pos = 0;
            self.read_end = n;
        }

        const byte = self.read_buffer[self.read_pos];
        self.read_pos += 1;
        return byte;
    }
};

fn trimCarriageReturnOwned(line: *std.Io.Writer.Allocating) ![]u8 {
    const written = line.written();
    if (written.len > 0 and written[written.len - 1] == '\r') {
        line.writer.end -= 1;
    }
    return try line.toOwnedSlice();
}

fn dataLineValue(line: []const u8) ?[]const u8 {
    if (std.mem.eql(u8, line, "data")) return "";
    if (!std.mem.startsWith(u8, line, "data:")) return null;

    var value = line[5..];
    if (value.len > 0 and value[0] == ' ') value = value[1..];
    return value;
}

fn findHeader(headers: []const http.Header, name: []const u8) ?[]const u8 {
    for (headers) |header| {
        if (std.ascii.eqlIgnoreCase(header.name, name)) return header.value;
    }
    return null;
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

test "messages stream serializes stream true and ignores extra stream" {
    var object: std.json.ObjectMap = .empty;
    defer object.deinit(std.testing.allocator);
    try object.put(std.testing.allocator, "stream", .{ .bool = false });

    const body = try json.stringifyRequest(std.testing.allocator, StreamingCreateRequest{ .request = .{
        .model = "anthropic/claude-sonnet-4",
        .messages = &.{Message{ .role = .user, .content = .{ .text = "Hello" } }},
        .extra_body = .{ .object = object },
    } });
    defer std.testing.allocator.free(body);

    try std.testing.expect(std.mem.indexOf(u8, body, "\"stream\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"stream\":false") == null);
}

test "messages stream sends POST /messages with event stream accept" {
    const body = try json.stringifyRequest(std.testing.allocator, StreamingCreateRequest{ .request = .{
        .model = "anthropic/claude-sonnet-4",
        .messages = &.{Message{ .role = .user, .content = .{ .text = "Hello" } }},
    } });
    defer std.testing.allocator.free(body);

    var prepared = try http.prepareRequest(std.testing.allocator, .{ .api_key = "test-key" }, .{
        .method = .POST,
        .path = "/messages",
        .body = body,
        .accept = "text/event-stream",
    }, .{});
    defer prepared.deinit();

    try std.testing.expectEqual(std.http.Method.POST, prepared.method);
    try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/messages", prepared.url);
    try std.testing.expectEqualStrings("text/event-stream", findHeader(prepared.headers, "accept").?);
    try std.testing.expectEqualStrings(body, prepared.body.?);
}

test "messages stream parses message start event" {
    var event = try parseStreamEvent(std.testing.allocator,
        \\{
        \\  "type": "message_start",
        \\  "message": {
        \\    "id": "msg_123",
        \\    "type": "message",
        \\    "role": "assistant",
        \\    "model": "anthropic/claude-sonnet-4",
        \\    "content": [],
        \\    "usage": { "input_tokens": 5, "output_tokens": 0 }
        \\  }
        \\}
    );
    defer event.deinit();

    try std.testing.expectEqualStrings("message_start", event.type.?);
    try std.testing.expectEqualStrings("msg_123", event.message.?.id.?);
    try std.testing.expectEqual(Role.assistant, event.message.?.role.?);
    try std.testing.expectEqual(@as(?u32, 5), event.message.?.usage.?.input_tokens);
}

test "messages stream parses text delta helper" {
    var event = try parseStreamEvent(std.testing.allocator,
        \\{
        \\  "type": "content_block_delta",
        \\  "index": 0,
        \\  "delta": { "type": "text_delta", "text": "Hello" }
        \\}
    );
    defer event.deinit();

    try std.testing.expectEqualStrings("content_block_delta", event.type.?);
    try std.testing.expectEqual(@as(?u32, 0), event.index);
    try std.testing.expectEqualStrings("Hello", event.textDelta().?);
}

test "messages stream parses error event" {
    var event = try parseStreamEvent(std.testing.allocator,
        \\{
        \\  "type": "error",
        \\  "error": { "type": "overloaded_error", "message": "busy" }
        \\}
    );
    defer event.deinit();

    try std.testing.expectEqualStrings("error", event.type.?);
    try std.testing.expect(event.error_value != null);
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
