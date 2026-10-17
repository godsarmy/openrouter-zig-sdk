//! Streaming chat completions and SSE parsing.

const std = @import("std");

const chat = @import("chat.zig");
const config_mod = @import("config.zig");
const errors = @import("errors.zig");
const http = @import("http.zig");
const json = @import("json.zig");
const options_mod = @import("options.zig");
const sse = @import("sse.zig");

pub const Error = error{
    MalformedSse,
    StreamTooLong,
    UnexpectedEndOfStream,
    Canceled,
    ApiError,
    OutOfMemory,
};

pub const CompletionStream = struct {
    state: *sse.State,

    pub fn next(self: *CompletionStream) !?CompletionChunk {
        if (self.state.done) return null;

        while (true) {
            const data = try self.state.nextDataEvent();
            const payload = data orelse return null;
            defer self.state.allocator.free(payload);

            var chunk = parseChunk(self.state.allocator, payload) catch |err| {
                self.state.done = true;
                return err;
            };
            if (chunk.choices.len == 0) {
                chunk.deinit();
                continue;
            }
            return chunk;
        }
    }

    pub fn deinit(self: *CompletionStream) void {
        self.state.deinit();
        self.* = undefined;
    }
};

pub const CompletionChunk = struct {
    arena: std.heap.ArenaAllocator,
    id: ?[]const u8 = null,
    model: ?[]const u8 = null,
    choices: []ChunkChoice,

    pub fn content(self: CompletionChunk) ?[]const u8 {
        if (self.choices.len == 0) return null;
        return self.choices[0].delta.content;
    }

    pub fn deinit(self: *CompletionChunk) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

pub const ChunkChoice = struct {
    index: u32 = 0,
    delta: Delta,
    finish_reason: ?[]const u8 = null,
};

pub const Delta = struct {
    role: ?chat.Role = null,
    content: ?[]const u8 = null,
    content_parts: ?[]chat.AssistantContentPart = null,
    tool_calls: ?[]chat.ToolCallDelta = null,
    reasoning: ?[]const u8 = null,
    reasoning_details: ?[]chat.ReasoningDetail = null,
    annotations: ?[]chat.Annotation = null,
    refusal: ?[]const u8 = null,
    images: ?[]chat.GeneratedImage = null,
    audio: ?std.json.Value = null,
    /// Original decoded delta object, owned by this chunk's arena.
    raw: std.json.Value = .null,
};

const WireCompletionChunk = struct {
    id: ?[]const u8 = null,
    model: ?[]const u8 = null,
    choices: []std.json.Value = &.{},
};

pub fn stream(client: anytype, request: chat.CompletionRequest, request_options: options_mod.RequestOptions) !CompletionStream {
    return streamWithHttpClient(client.allocator, &client.http_client, client.config, request, request_options);
}

pub fn streamWithHttpClient(
    allocator: std.mem.Allocator,
    client: *std.http.Client,
    config: config_mod.Config,
    request: chat.CompletionRequest,
    request_options: options_mod.RequestOptions,
) !CompletionStream {
    var streaming_request = request;
    streaming_request.stream = true;

    const body = try json.stringifyRequest(allocator, streaming_request);
    errdefer allocator.free(body);

    var prepared = try http.prepareRequest(allocator, config, .{
        .method = .POST,
        .path = "/chat/completions",
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

    const response = req.receiveHead(&.{}) catch |err| switch (err) {
        error.ReadFailed => {
            if (req.connection) |connection| {
                if (connection.getReadError()) |read_error| switch (read_error) {
                    error.Canceled => return error.Canceled,
                    else => {},
                };
            }
            return error.ReadFailed;
        },
        else => |e| return e,
    };
    if (errors.isErrorStatus(@backingInt(response.head.status))) return error.ApiError;

    const state = try allocator.create(sse.State);
    state.* = .{
        .allocator = allocator,
        .body = body,
        .prepared = prepared,
        .std_headers = std_headers,
        .request = req,
        .response = response,
        .reader = undefined,
    };
    state.initReader();

    return .{ .state = state };
}

pub const SseParser = sse.Parser;

pub fn parseChunk(allocator: std.mem.Allocator, payload: []const u8) !CompletionChunk {
    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const arena_allocator = arena.allocator();

    const owned_payload = try arena_allocator.dupe(u8, payload);
    const parsed = try json.parseResponseLeaky(WireCompletionChunk, arena_allocator, owned_payload);
    const choices = try parseChoices(arena_allocator, parsed.choices);

    return .{
        .arena = arena,
        .id = parsed.id,
        .model = parsed.model,
        .choices = choices,
    };
}

fn parseChoices(allocator: std.mem.Allocator, values: []std.json.Value) ![]ChunkChoice {
    const choices = try allocator.alloc(ChunkChoice, values.len);
    for (values, choices) |value, *choice| {
        const object = if (value == .object) value.object else return error.UnexpectedToken;
        const delta_value = object.get("delta") orelse return error.UnexpectedToken;
        choice.* = .{
            .index = uintField(object, "index") orelse 0,
            .delta = try parseDelta(allocator, delta_value),
            .finish_reason = stringField(object, "finish_reason"),
        };
    }
    return choices;
}

fn parseDelta(allocator: std.mem.Allocator, value: std.json.Value) !Delta {
    const object = if (value == .object) value.object else return error.UnexpectedToken;
    var delta: Delta = .{ .raw = value };
    if (stringField(object, "role")) |role| delta.role = std.meta.stringToEnum(chat.Role, role) orelse return error.InvalidEnumTag;
    if (object.get("content")) |content| switch (content) {
        .string => |text| delta.content = text,
        .array => |parts| delta.content_parts = try chat.parseAssistantContentParts(allocator, parts.items),
        .null => {},
        else => return error.UnexpectedToken,
    };
    delta.tool_calls = try chat.parseToolCallDeltas(allocator, object.get("tool_calls"));
    delta.reasoning = stringField(object, "reasoning");
    delta.refusal = stringField(object, "refusal");
    delta.reasoning_details = try chat.parseReasoningDetails(allocator, object.get("reasoning_details"));
    delta.annotations = try chat.parseAnnotations(allocator, object.get("annotations"));
    delta.images = try chat.parseImages(allocator, object.get("images"));
    delta.audio = object.get("audio");
    return delta;
}

fn stringField(object: std.json.ObjectMap, key: []const u8) ?[]const u8 {
    const value = object.get(key) orelse return null;
    return if (value == .string) value.string else null;
}
fn uintField(object: std.json.ObjectMap, key: []const u8) ?u32 {
    const value = object.get(key) orelse return null;
    return if (value == .integer and value.integer >= 0 and value.integer <= std.math.maxInt(u32)) @intCast(value.integer) else null;
}

test "SSE parser returns data events and skips comments" {
    var parser: SseParser = .{
        .allocator = std.testing.allocator,
        .input = ": keepalive\n\ndata: hello\n\ndata: world\n\n",
    };

    const first = (try parser.nextData()).?;
    defer std.testing.allocator.free(first);
    try std.testing.expectEqualStrings("hello", first);

    const second = (try parser.nextData()).?;
    defer std.testing.allocator.free(second);
    try std.testing.expectEqualStrings("world", second);
}

test "SSE parser joins multiple data lines" {
    var parser: SseParser = .{
        .allocator = std.testing.allocator,
        .input = "data: hello\ndata: world\n\n",
    };

    const data = (try parser.nextData()).?;
    defer std.testing.allocator.free(data);
    try std.testing.expectEqualStrings("hello\nworld", data);
}

test "SSE parser handles CRLF and done" {
    var parser: SseParser = .{
        .allocator = std.testing.allocator,
        .input = "data: hello\r\n\r\ndata: [DONE]\r\n\r\n",
    };

    const data = (try parser.nextData()).?;
    defer std.testing.allocator.free(data);
    try std.testing.expectEqualStrings("hello", data);

    try std.testing.expectEqual(null, try parser.nextData());
    try std.testing.expectEqual(null, try parser.nextData());
}

test "SSE parser ignores event id and retry fields" {
    var parser: SseParser = .{
        .allocator = std.testing.allocator,
        .input = "event: message\nid: 1\nretry: 100\next: future\ndata: hello\n\n",
    };

    const data = (try parser.nextData()).?;
    defer std.testing.allocator.free(data);
    try std.testing.expectEqualStrings("hello", data);
}

test "SSE parser accepts empty data line" {
    var parser: SseParser = .{
        .allocator = std.testing.allocator,
        .input = "data\n\n",
    };

    const data = (try parser.nextData()).?;
    defer std.testing.allocator.free(data);
    try std.testing.expectEqualStrings("", data);
}

test "SSE parser rejects malformed fields" {
    var parser: SseParser = .{
        .allocator = std.testing.allocator,
        .input = "wat\n\n",
    };

    try std.testing.expectError(error.MalformedSse, parser.nextData());
}

test "parse stream chunk JSON" {
    var chunk = try parseChunk(std.testing.allocator,
        \\{"id":"gen-1","model":"m","choices":[{"index":0,"delta":{"role":"assistant","content":"hi"}}]}
    );
    defer chunk.deinit();

    try std.testing.expectEqualStrings("gen-1", chunk.id.?);
    try std.testing.expectEqualStrings("hi", chunk.content().?);
    try std.testing.expectEqual(chat.Role.assistant, chunk.choices[0].delta.role.?);
}

test "parse stream chunks preserve indexed tool call fragments and rich fields" {
    var first = try parseChunk(std.testing.allocator,
        \\{"choices":[{"index":1,"delta":{"tool_calls":[{"index":0,"id":"call","type":"function","function":{"name":"weather","arguments":"{\"city\":"}}],"reasoning":"think","refusal":null,"reasoning_details":[{"type":"future","x":1}],"future_delta":"kept"}}]}
    );
    defer first.deinit();
    var second = try parseChunk(std.testing.allocator,
        \\{"choices":[{"index":1,"delta":{"tool_calls":[{"index":0,"function":{"arguments":"\"Paris\"}"}}]},"finish_reason":"tool_calls"}]}
    );
    defer second.deinit();

    const delta = first.choices[0].delta;
    try std.testing.expectEqual(@as(u32, 0), delta.tool_calls.?[0].index);
    try std.testing.expectEqualStrings("{\"city\":", delta.tool_calls.?[0].function.arguments.?);
    try std.testing.expectEqualStrings("\"Paris\"}", second.choices[0].delta.tool_calls.?[0].function.arguments.?);
    try std.testing.expect(second.choices[0].delta.tool_calls.?[0].id == null);
    try std.testing.expect(second.choices[0].delta.tool_calls.?[0].function.name == null);
    try std.testing.expectEqualStrings("tool_calls", second.choices[0].finish_reason.?);
    try std.testing.expect(delta.reasoning_details.?[0] == .raw);
    try std.testing.expectEqualStrings("kept", delta.raw.object.get("future_delta").?.string);
}

test "stream chunks accept role-only, terminal usage, and null optional arrays" {
    var role_only = try parseChunk(std.testing.allocator, "{\"choices\":[{\"index\":0,\"delta\":{\"role\":\"assistant\",\"tool_calls\":null,\"reasoning_details\":null,\"annotations\":null,\"images\":null}}]}");
    defer role_only.deinit();
    try std.testing.expectEqual(chat.Role.assistant, role_only.choices[0].delta.role.?);
    try std.testing.expect(role_only.choices[0].delta.tool_calls == null);

    var empty_delta = try parseChunk(std.testing.allocator, "{\"choices\":[{\"index\":0,\"delta\":{}}]}");
    defer empty_delta.deinit();
    try std.testing.expect(empty_delta.content() == null);

    var terminal = try parseChunk(std.testing.allocator, "{\"choices\":[],\"usage\":{\"total_tokens\":1}}");
    defer terminal.deinit();
    try std.testing.expectEqual(@as(usize, 0), terminal.choices.len);
}

test "stream chunk rejects scalar content" {
    try std.testing.expectError(error.UnexpectedToken, parseChunk(std.testing.allocator, "{\"choices\":[{\"index\":0,\"delta\":{\"content\":1}}]}"));
}
