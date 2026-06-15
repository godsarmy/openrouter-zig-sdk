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
};

const WireCompletionChunk = struct {
    id: ?[]const u8 = null,
    model: ?[]const u8 = null,
    choices: []ChunkChoice = &.{},
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
    if (errors.isErrorStatus(@intFromEnum(response.head.status))) return error.ApiError;

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
    state.reader = state.response.reader(&state.transfer_buffer);

    return .{ .state = state };
}

pub const SseParser = sse.Parser;

pub fn parseChunk(allocator: std.mem.Allocator, payload: []const u8) !CompletionChunk {
    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const arena_allocator = arena.allocator();

    const owned_payload = try arena_allocator.dupe(u8, payload);
    const parsed = try json.parseResponseLeaky(WireCompletionChunk, arena_allocator, owned_payload);

    return .{
        .arena = arena,
        .id = parsed.id,
        .model = parsed.model,
        .choices = parsed.choices,
    };
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
