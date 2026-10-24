//! OpenAI-compatible Responses API.

const std = @import("std");

const config_mod = @import("config.zig");
const errors = @import("errors.zig");
const chat_mod = @import("chat.zig");
const http = @import("http.zig");
const json = @import("json.zig");
const options_mod = @import("options.zig");
const sse = @import("sse.zig");

pub const CreateRequest = struct {
    model: []const u8,
    input: Input,
    max_output_tokens: ?u32 = null,
    temperature: ?f32 = null,
    top_p: ?f32 = null,
    reasoning: ?std.json.Value = null,
    tools: ?[]const ServerTool = null,
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
    try jws.objectField("input");
    try jws.write(self.input);
    if (self.max_output_tokens) |value| {
        try jws.objectField("max_output_tokens");
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
    if (self.reasoning) |value| {
        try jws.objectField("reasoning");
        try jws.write(value);
    }
    if (self.tools) |value| {
        try jws.objectField("tools");
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
    if (streaming) {
        try jws.objectField("stream");
        try jws.write(true);
    }
    try jws.endObject();
}

pub const ServerTool = chat_mod.ServerTool;

pub const Input = union(enum) {
    text: []const u8,
    items: []const std.json.Value,
    value: std.json.Value,

    pub fn jsonStringify(self: Input, jws: anytype) !void {
        switch (self) {
            .text => |value| try jws.write(value),
            .items => |value| try jws.write(value),
            .value => |value| try jws.write(value),
        }
    }
};

pub const CreateResponse = struct {
    arena: std.heap.ArenaAllocator,
    response_metadata: http.ResponseMetadata = .{},
    id: ?[]const u8 = null,
    object: ?[]const u8 = null,
    created_at: ?i64 = null,
    model: ?[]const u8 = null,
    status: ?[]const u8 = null,
    /// Raw failure details, owned by this response until `deinit`.
    @"error": ?std.json.Value = null,
    /// Raw incomplete-response details, owned by this response until `deinit`.
    incomplete_details: ?std.json.Value = null,
    output: ?[]std.json.Value = null,
    usage: ?Usage = null,
    openrouter_metadata: ?std.json.Value = null,

    pub fn deinit(self: *CreateResponse) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

pub const Usage = struct {
    input_tokens: ?u32 = null,
    output_tokens: ?u32 = null,
    total_tokens: ?u32 = null,
    input_tokens_details: ?std.json.Value = null,
    output_tokens_details: ?std.json.Value = null,
};

const WireCreateResponse = struct {
    id: ?[]const u8 = null,
    object: ?[]const u8 = null,
    created_at: ?i64 = null,
    model: ?[]const u8 = null,
    status: ?[]const u8 = null,
    @"error": ?std.json.Value = null,
    incomplete_details: ?std.json.Value = null,
    output: ?[]std.json.Value = null,
    usage: ?Usage = null,
    openrouter_metadata: ?std.json.Value = null,
};

pub fn create(client: anytype, request: CreateRequest, request_options: options_mod.RequestOptions) !CreateResponse {
    return createWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, request, request_options);
}

pub const ResponsesStream = struct {
    state: *sse.State,

    pub fn next(self: *ResponsesStream) !?ResponsesStreamEvent {
        if (self.state.done) return null;
        const data = try self.state.nextDataEvent() orelse return null;
        defer self.state.allocator.free(data);

        const event = parseStreamEvent(self.state.allocator, data) catch |err| {
            self.state.done = true;
            return err;
        };
        markTerminal(self.state, event);
        return event;
    }

    pub fn deinit(self: *ResponsesStream) void {
        self.state.deinit();
        self.* = undefined;
    }
};

pub const ResponsesStreamEvent = struct {
    arena: std.heap.ArenaAllocator,
    raw: std.json.Value,
    type: ?[]const u8 = null,
    sequence_number: ?i64 = null,
    output_index: ?u32 = null,
    item_id: ?[]const u8 = null,
    content_index: ?u32 = null,
    response: ?std.json.Value = null,
    item: ?std.json.Value = null,
    part: ?std.json.Value = null,
    delta: ?[]const u8 = null,
    text: ?[]const u8 = null,
    arguments: ?[]const u8 = null,
    name: ?[]const u8 = null,
    code: ?[]const u8 = null,
    message: ?[]const u8 = null,
    param: ?[]const u8 = null,
    error_value: ?std.json.Value = null,

    /// Output-text deltas only; function-call argument deltas are exposed by `functionArgumentsDelta`.
    pub fn textDelta(self: ResponsesStreamEvent) ?[]const u8 {
        const event_type = self.type orelse return null;
        if (std.mem.eql(u8, event_type, "response.output_text.delta")) return self.delta;
        return null;
    }

    pub fn reasoningDelta(self: ResponsesStreamEvent) ?[]const u8 {
        const event_type = self.type orelse return null;
        if (std.mem.eql(u8, event_type, "response.reasoning_text.delta") or
            std.mem.eql(u8, event_type, "response.reasoning_summary_text.delta") or
            std.mem.eql(u8, event_type, "response.reasoning.delta")) return self.delta;
        return null;
    }

    /// Incremental function-call arguments. Completed arguments from `.done` remain in `arguments`.
    pub fn functionArgumentsDelta(self: ResponsesStreamEvent) ?[]const u8 {
        const event_type = self.type orelse return null;
        if (std.mem.eql(u8, event_type, "response.function_call_arguments.delta")) return self.delta;
        return null;
    }

    pub fn isTerminal(self: ResponsesStreamEvent) bool {
        const event_type = self.type orelse return false;
        return std.mem.eql(u8, event_type, "response.completed") or
            std.mem.eql(u8, event_type, "response.done") or
            std.mem.eql(u8, event_type, "response.failed") or
            std.mem.eql(u8, event_type, "response.incomplete") or
            std.mem.eql(u8, event_type, "error");
    }

    pub fn isSuccess(self: ResponsesStreamEvent) bool {
        const event_type = self.type orelse return false;
        return std.mem.eql(u8, event_type, "response.completed") or std.mem.eql(u8, event_type, "response.done");
    }

    pub fn deinit(self: *ResponsesStreamEvent) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

fn markTerminal(state: *sse.State, event: ResponsesStreamEvent) void {
    if (event.isTerminal()) state.done = true;
}

pub fn stream(client: anytype, request: CreateRequest, request_options: options_mod.RequestOptions) !ResponsesStream {
    return streamWithHttpClient(client.allocator, &client.http_client, client.config, request, request_options);
}

pub fn streamWithHttpClient(allocator: std.mem.Allocator, client: *std.http.Client, config: config_mod.Config, request: CreateRequest, request_options: options_mod.RequestOptions) !ResponsesStream {
    const body = try json.stringifyRequest(allocator, StreamingCreateRequest{ .request = request });
    errdefer allocator.free(body);
    var prepared = try http.prepareRequest(allocator, config, .{ .method = .POST, .path = "/responses", .body = body, .accept = "text/event-stream" }, request_options);
    errdefer prepared.deinit();
    const std_headers = try allocator.alloc(std.http.Header, prepared.headers.len);
    errdefer allocator.free(std_headers);
    for (prepared.headers, std_headers) |header, *std_header| std_header.* = .{ .name = header.name, .value = header.value };
    const uri = try std.Uri.parse(prepared.url);
    var req = try client.request(prepared.method, uri, .{ .extra_headers = std_headers, .redirect_behavior = .unhandled });
    errdefer req.deinit();
    try req.sendBodyComplete(body);
    const response = req.receiveHead(&.{}) catch |err| switch (err) {
        error.ReadFailed => {
            if (req.connection) |connection| if (connection.getReadError()) |read_error| switch (read_error) {
                error.Canceled => return error.Canceled,
                else => {},
            };
            return error.ReadFailed;
        },
        else => |e| return e,
    };
    if (errors.isErrorStatus(@backingInt(response.head.status))) return error.ApiError;
    const state = try allocator.create(sse.State);
    state.* = .{ .allocator = allocator, .body = body, .prepared = prepared, .std_headers = std_headers, .request = req, .response = response, .reader = undefined };
    state.initReader();
    return .{ .state = state };
}

pub fn parseStreamEvent(allocator: std.mem.Allocator, payload: []const u8) !ResponsesStreamEvent {
    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const arena_allocator = arena.allocator();
    const owned_payload = try arena_allocator.dupe(u8, payload);
    const raw = try json.parseResponseLeaky(std.json.Value, arena_allocator, owned_payload);
    const object = if (raw == .object) raw.object else return error.UnexpectedToken;
    return .{
        .arena = arena,
        .raw = raw,
        .type = stringField(object, "type"),
        .sequence_number = intField(object, "sequence_number"),
        .output_index = unsignedField(object, "output_index"),
        .item_id = stringField(object, "item_id"),
        .content_index = unsignedField(object, "content_index"),
        .response = object.get("response"),
        .item = object.get("item"),
        .part = object.get("part"),
        .delta = stringField(object, "delta"),
        .text = stringField(object, "text"),
        .arguments = stringField(object, "arguments"),
        .name = stringField(object, "name"),
        .code = stringField(object, "code"),
        .message = stringField(object, "message"),
        .param = stringField(object, "param"),
        .error_value = object.get("error"),
    };
}

fn stringField(object: std.json.ObjectMap, key: []const u8) ?[]const u8 {
    const value = object.get(key) orelse return null;
    return if (value == .string) value.string else null;
}
fn intField(object: std.json.ObjectMap, key: []const u8) ?i64 {
    const value = object.get(key) orelse return null;
    return if (value == .integer) value.integer else null;
}
fn unsignedField(object: std.json.ObjectMap, key: []const u8) ?u32 {
    const value = intField(object, key) orelse return null;
    return std.math.cast(u32, value);
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
        .path = "/responses",
        .body = body,
    }, request_options);
    defer prepared.deinit();

    var response = try transport.execute(allocator, prepared);
    defer response.deinit();

    return parseCreateResponse(allocator, response);
}

pub fn parseCreateResponse(allocator: std.mem.Allocator, response: http.HttpResponse) !CreateResponse {
    if (errors.isErrorStatus(@backingInt(response.status))) return error.ApiError;

    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const arena_allocator = arena.allocator();

    const owned_body = try arena_allocator.dupe(u8, response.body);
    const parsed = try json.parseResponseLeaky(WireCreateResponse, arena_allocator, owned_body);
    return .{
        .arena = arena,
        .response_metadata = try http.ResponseMetadata.fromHttpResponse(arena_allocator, response),
        .id = parsed.id,
        .object = parsed.object,
        .created_at = parsed.created_at,
        .model = parsed.model,
        .status = parsed.status,
        .@"error" = parsed.@"error",
        .incomplete_details = parsed.incomplete_details,
        .output = parsed.output,
        .usage = parsed.usage,
        .openrouter_metadata = parsed.openrouter_metadata,
    };
}

test "responses create serializes text input" {
    const body = try json.stringifyRequest(std.testing.allocator, CreateRequest{
        .model = "openai/o4-mini",
        .input = .{ .text = "What is the meaning of life?" },
        .max_output_tokens = 9000,
    });
    defer std.testing.allocator.free(body);

    try std.testing.expect(std.mem.indexOf(u8, body, "\"model\":\"openai/o4-mini\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"input\":\"What is the meaning of life?\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"stream\"") == null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"max_output_tokens\":9000") != null);
}

test "responses create merges extra body" {
    var object: std.json.ObjectMap = .empty;
    defer object.deinit(std.testing.allocator);
    try object.put(std.testing.allocator, "parallel_tool_calls", .{ .bool = false });

    const body = try json.stringifyRequest(std.testing.allocator, CreateRequest{
        .model = "openai/o4-mini",
        .input = .{ .text = "Hello" },
        .extra_body = .{ .object = object },
    });
    defer std.testing.allocator.free(body);

    try std.testing.expect(std.mem.indexOf(u8, body, "\"parallel_tool_calls\":false") != null);
}

test "responses create serializes typed server tools" {
    const tools = &.{ServerTool{ .web_search = .{
        .max_results = 3,
        .search_context_size = .medium,
        .allowed_domains = &.{"example.com"},
    } }};

    const body = try json.stringifyRequest(std.testing.allocator, CreateRequest{
        .model = "openai/o4-mini",
        .input = .{ .text = "Search for sources" },
        .tools = tools,
    });
    defer std.testing.allocator.free(body);

    try std.testing.expect(std.mem.indexOf(u8, body, "\"tools\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"type\":\"openrouter:web_search\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"search_context_size\":\"medium\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"allowed_domains\"") != null);
}

test "responses create ignores stream from extra body" {
    var object: std.json.ObjectMap = .empty;
    defer object.deinit(std.testing.allocator);
    try object.put(std.testing.allocator, "stream", .{ .bool = true });

    const body = try json.stringifyRequest(std.testing.allocator, CreateRequest{
        .model = "openai/o4-mini",
        .input = .{ .text = "Hello" },
        .extra_body = .{ .object = object },
    });
    defer std.testing.allocator.free(body);

    try std.testing.expect(std.mem.indexOf(u8, body, "\"stream\"") == null);
}

test "responses stream forces stream despite extra body override" {
    var object: std.json.ObjectMap = .empty;
    defer object.deinit(std.testing.allocator);
    try object.put(std.testing.allocator, "stream", .{ .bool = false });
    const body = try json.stringifyRequest(std.testing.allocator, StreamingCreateRequest{
        .request = .{ .model = "openai/o4-mini", .input = .{ .text = "Hello" }, .extra_body = .{ .object = object } },
    });
    defer std.testing.allocator.free(body);
    try std.testing.expectEqual(@as(usize, 1), std.mem.count(u8, body, "\"stream\""));
    try std.testing.expect(std.mem.indexOf(u8, body, "\"stream\":true") != null);
}

test "responses stream prepares SSE request" {
    const body = try json.stringifyRequest(std.testing.allocator, StreamingCreateRequest{ .request = .{ .model = "openai/o4-mini", .input = .{ .text = "Hello" } } });
    defer std.testing.allocator.free(body);
    var prepared = try http.prepareRequest(std.testing.allocator, .{ .api_key = "test-key" }, .{ .method = .POST, .path = "/responses", .body = body, .accept = "text/event-stream" }, .{});
    defer prepared.deinit();
    try std.testing.expectEqual(std.http.Method.POST, prepared.method);
    try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/responses", prepared.url);
    try std.testing.expectEqualStrings(body, prepared.body.?);
    var saw_accept = false;
    for (prepared.headers) |header| {
        if (std.ascii.eqlIgnoreCase(header.name, "accept")) saw_accept = std.mem.eql(u8, header.value, "text/event-stream");
    }
    try std.testing.expect(saw_accept);
}

test "responses stream parses known aliases and preserves unknown raw data" {
    var text = try parseStreamEvent(std.testing.allocator, "{\"type\":\"response.output_text.delta\",\"sequence_number\":2,\"output_index\":0,\"item_id\":\"msg_1\",\"content_index\":1,\"delta\":\"hello\",\"future\":true}");
    defer text.deinit();
    try std.testing.expectEqualStrings("hello", text.textDelta().?);
    try std.testing.expectEqual(@as(?i64, 2), text.sequence_number);
    try std.testing.expect(text.raw.object.get("future") != null);

    var function = try parseStreamEvent(std.testing.allocator, "{\"type\":\"response.function_call_arguments.delta\",\"delta\":\"{\\\"x\\\":1}\"}");
    defer function.deinit();
    try std.testing.expectEqualStrings("{\"x\":1}", function.functionArgumentsDelta().?);
    try std.testing.expect(function.textDelta() == null);

    inline for ([_][]const u8{ "response.reasoning_text.delta", "response.reasoning_summary_text.delta", "response.reasoning.delta" }) |event_type| {
        var reasoning = try parseTestEvent(std.testing.allocator, event_type, "think");
        defer reasoning.deinit();
        try std.testing.expectEqualStrings("think", reasoning.reasoningDelta().?);
    }

    var function_done = try parseStreamEvent(std.testing.allocator, "{\"type\":\"response.function_call_arguments.done\",\"arguments\":\"{\\\"x\\\":1}\"}");
    defer function_done.deinit();
    try std.testing.expectEqualStrings("{\"x\":1}", function_done.arguments.?);
    try std.testing.expect(function_done.functionArgumentsDelta() == null);

    var unknown = try parseStreamEvent(std.testing.allocator, "{\"type\":\"response.future_event\",\"opaque\":{\"value\":1}}");
    defer unknown.deinit();
    try std.testing.expect(!unknown.isTerminal());
    try std.testing.expect(unknown.raw.object.get("opaque") != null);
}

test "responses stream malformed payload returns an error" {
    try std.testing.expectError(error.SyntaxError, parseStreamEvent(std.testing.allocator, "not json"));
    try std.testing.expectError(error.UnexpectedToken, parseStreamEvent(std.testing.allocator, "[]"));
}

test "responses stream lifecycle terminal classification and state transition" {
    inline for ([_][]const u8{ "response.completed", "response.done" }) |event_type| {
        var event = try parseTestEvent(std.testing.allocator, event_type, null);
        defer event.deinit();
        try std.testing.expect(event.isTerminal() and event.isSuccess());
    }
    inline for ([_][]const u8{ "response.failed", "response.incomplete", "error" }) |event_type| {
        var event = try parseTestEvent(std.testing.allocator, event_type, null);
        defer event.deinit();
        try std.testing.expect(event.isTerminal() and !event.isSuccess());
        var state: sse.State = undefined;
        state.done = false;
        markTerminal(&state, event);
        try std.testing.expect(state.done);
    }
    var created = try parseStreamEvent(std.testing.allocator, "{\"type\":\"response.created\"}");
    defer created.deinit();
    try std.testing.expect(!created.isTerminal());
}

test "responses stream next stops deterministically after terminal state" {
    var state: sse.State = undefined;
    state.done = true;
    var responses_stream = ResponsesStream{ .state = &state };
    try std.testing.expect((try responses_stream.next()) == null);
}

fn parseTestEvent(allocator: std.mem.Allocator, event_type: []const u8, delta: ?[]const u8) !ResponsesStreamEvent {
    const payload = if (delta) |value|
        try std.fmt.allocPrint(allocator, "{{\"type\":\"{s}\",\"delta\":\"{s}\"}}", .{ event_type, value })
    else
        try std.fmt.allocPrint(allocator, "{{\"type\":\"{s}\"}}", .{event_type});
    defer allocator.free(payload);
    return parseStreamEvent(allocator, payload);
}

test "responses create parses response and ignores unknown fields" {
    const body =
        \\{
        \\  "id": "resp_123",
        \\  "object": "response",
        \\  "created_at": 1710000000,
        \\  "model": "openai/o4-mini",
        \\  "status": "completed",
        \\  "output": [
        \\    { "type": "message", "role": "assistant", "status": "completed", "content": [{ "type": "output_text", "text": "Hello" }] }
        \\  ],
        \\  "usage": { "input_tokens": 5, "output_tokens": 7, "total_tokens": 12 },
        \\  "unknown": true
        \\}
    ;

    var result = try createWithTransport(std.testing.allocator, config_mod.Config{ .api_key = "test-key" }, http.FakeTransport{ .body = body }, .{
        .model = "openai/o4-mini",
        .input = .{ .text = "Hello" },
    }, .{});
    defer result.deinit();

    try std.testing.expectEqualStrings("resp_123", result.id.?);
    try std.testing.expectEqualStrings("response", result.object.?);
    try std.testing.expectEqualStrings("completed", result.status.?);
    try std.testing.expectEqual(@as(usize, 1), result.output.?.len);
    try std.testing.expectEqual(@as(?u32, 12), result.usage.?.total_tokens);
}

test "responses create sends POST /responses" {
    const body = try json.stringifyRequest(std.testing.allocator, CreateRequest{
        .model = "openai/o4-mini",
        .input = .{ .text = "Hello" },
    });
    defer std.testing.allocator.free(body);

    var prepared = try http.prepareRequest(std.testing.allocator, .{ .api_key = "test-key" }, .{
        .method = .POST,
        .path = "/responses",
        .body = body,
    }, .{});
    defer prepared.deinit();

    try std.testing.expectEqual(std.http.Method.POST, prepared.method);
    try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/responses", prepared.url);
    try std.testing.expectEqualStrings(body, prepared.body.?);
}

test "responses create maps error status to ApiError" {
    try std.testing.expectError(error.ApiError, createWithTransport(
        std.testing.allocator,
        config_mod.Config{ .api_key = "test-key" },
        http.FakeTransport{ .status = .bad_request, .body = "{\"error\":{\"message\":\"bad request\"}}" },
        .{ .model = "openai/o4-mini", .input = .{ .text = "Hello" } },
        .{},
    ));
}

test "responses create preserves failed response error and nested metadata through transport" {
    const body =
        \\{"status":"failed","error":{"code":"server_error","message":"Provider failed","metadata":{"provider_name":"Example","alignment":{"calls":[{"outcome":"unavailable","reason":"evaluator_error"}]},"future":{"values":[null,true,42,{"opaque":"kept"}]}},"future_error_field":["extra"]}}
    ;
    var result = try createWithTransport(std.testing.allocator, .{ .api_key = "test-key" }, http.FakeTransport{ .body = body }, .{
        .model = "openai/o4-mini",
        .input = .{ .text = "Hello" },
    }, .{});
    defer result.deinit();

    try std.testing.expectEqualStrings("failed", result.status.?);
    const failure = result.@"error".?.object;
    try std.testing.expectEqualStrings("server_error", failure.get("code").?.string);
    try std.testing.expectEqualStrings("Provider failed", failure.get("message").?.string);
    const metadata = failure.get("metadata").?.object;
    try std.testing.expectEqualStrings("Example", metadata.get("provider_name").?.string);
    const call = metadata.get("alignment").?.object.get("calls").?.array.items[0].object;
    try std.testing.expectEqualStrings("evaluator_error", call.get("reason").?.string);
    const values = metadata.get("future").?.object.get("values").?.array.items;
    try std.testing.expectEqual(@as(usize, 4), values.len);
    try std.testing.expect(values[0] == .null);
    try std.testing.expect(values[1].bool);
    try std.testing.expectEqual(@as(i64, 42), values[2].integer);
    try std.testing.expectEqualStrings("kept", values[3].object.get("opaque").?.string);
    try std.testing.expectEqualStrings("extra", failure.get("future_error_field").?.array.items[0].string);
    try std.testing.expect(result.incomplete_details == null);
}

test "responses create owns incomplete details independently of HTTP body" {
    var response: http.HttpResponse = .{
        .allocator = std.testing.allocator,
        .status = .ok,
        .body = try std.testing.allocator.dupe(u8,
            \\{"status":"incomplete","error":null,"incomplete_details":{"reason":"max_output_tokens","details":{"provider":{"limits":[123,"future"]},"retryable":false}}}
        ),
    };
    var result = blk: {
        defer response.deinit();
        const parsed = try parseCreateResponse(std.testing.allocator, response);
        @memset(response.body, 'x');
        break :blk parsed;
    };
    defer result.deinit();

    try std.testing.expectEqualStrings("incomplete", result.status.?);
    try std.testing.expect(result.@"error" == null);
    const incomplete = result.incomplete_details.?.object;
    try std.testing.expectEqualStrings("max_output_tokens", incomplete.get("reason").?.string);
    const details = incomplete.get("details").?.object;
    try std.testing.expect(!details.get("retryable").?.bool);
    const limits = details.get("provider").?.object.get("limits").?.array.items;
    try std.testing.expectEqual(@as(i64, 123), limits[0].integer);
    try std.testing.expectEqualStrings("future", limits[1].string);
}

test "responses create completed response accepts omitted and null failure details" {
    for ([_][]const u8{
        "{\"status\":\"completed\"}",
        "{\"status\":\"completed\",\"error\":null,\"incomplete_details\":null}",
    }) |body| {
        var result = try createWithTransport(std.testing.allocator, .{ .api_key = "test-key" }, http.FakeTransport{ .body = body }, .{
            .model = "openai/o4-mini",
            .input = .{ .text = "Hello" },
        }, .{});
        defer result.deinit();
        try std.testing.expectEqualStrings("completed", result.status.?);
        try std.testing.expect(result.@"error" == null);
        try std.testing.expect(result.incomplete_details == null);
    }
}

test "responses create HTTP errors take precedence over response failure details and invalid JSON" {
    for ([_]std.http.Status{ .bad_request, .too_many_requests, .internal_server_error, .bad_gateway }) |status| {
        for ([_][]const u8{
            "{\"status\":\"failed\",\"error\":{\"code\":\"server_error\",\"metadata\":{\"nested\":[true]}},\"incomplete_details\":{\"reason\":\"content_filter\"}}",
            "not JSON",
        }) |body| {
            try std.testing.expectError(error.ApiError, createWithTransport(
                std.testing.allocator,
                .{ .api_key = "test-key" },
                http.FakeTransport{ .status = status, .body = body },
                .{ .model = "openai/o4-mini", .input = .{ .text = "Hello" } },
                .{},
            ));
        }
    }
}
