//! OpenAI-compatible Responses API.

const std = @import("std");

const config_mod = @import("config.zig");
const errors = @import("errors.zig");
const http = @import("http.zig");
const json = @import("json.zig");
const options_mod = @import("options.zig");

pub const CreateRequest = struct {
    model: []const u8,
    input: Input,
    max_output_tokens: ?u32 = null,
    temperature: ?f32 = null,
    top_p: ?f32 = null,
    reasoning: ?std.json.Value = null,
    tools: ?[]const std.json.Value = null,
    provider: ?std.json.Value = null,
    extra_body: ?std.json.Value = null,

    pub fn jsonStringify(self: CreateRequest, jws: anytype) !void {
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
        try jws.endObject();
    }
};

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
    output: ?[]std.json.Value = null,
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
        .path = "/responses",
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
        .response_metadata = try http.ResponseMetadata.fromHttpResponse(arena_allocator, response),
        .id = parsed.id,
        .object = parsed.object,
        .created_at = parsed.created_at,
        .model = parsed.model,
        .status = parsed.status,
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
