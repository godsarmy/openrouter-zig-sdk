//! Streaming chat completions and SSE parsing.

const std = @import("std");

const chat = @import("chat.zig");
const config_mod = @import("config.zig");
const errors = @import("errors.zig");
const http = @import("http.zig");
const json = @import("json.zig");
const options_mod = @import("options.zig");

const max_line_len = 64 * 1024;
const max_event_len = 1024 * 1024;

pub const Error = error{
    MalformedSse,
    StreamTooLong,
    UnexpectedEndOfStream,
    ApiError,
    OutOfMemory,
};

pub const CompletionStream = struct {
    state: *State,

    pub fn next(self: *CompletionStream) !?CompletionChunk {
        if (self.state.done) return null;

        while (true) {
            const data = try self.state.nextDataEvent();
            const payload = data orelse return null;
            defer self.state.allocator.free(payload);

            var chunk = try parseChunk(self.state.allocator, payload);
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

    const response = try req.receiveHead(&.{});
    if (errors.isErrorStatus(@intFromEnum(response.head.status))) return error.ApiError;

    const state = try allocator.create(State);
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

const State = struct {
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

    fn deinit(self: *State) void {
        self.request.deinit();
        self.allocator.free(self.std_headers);
        self.prepared.deinit();
        self.allocator.free(self.body);
        const allocator = self.allocator;
        self.* = undefined;
        allocator.destroy(self);
    }

    fn nextDataEvent(self: *State) !?[]u8 {
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

    fn readLineAlloc(self: *State) !?[]u8 {
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

    fn readByte(self: *State) !?u8 {
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

pub const SseParser = struct {
    allocator: std.mem.Allocator,
    input: []const u8,
    index: usize = 0,
    done: bool = false,

    pub fn nextData(self: *SseParser) !?[]u8 {
        if (self.done) return null;

        while (true) {
            var event_data: std.Io.Writer.Allocating = .init(self.allocator);
            defer event_data.deinit();
            var saw_data = false;

            while (true) {
                const maybe_line = try self.nextLine();
                const line = maybe_line orelse {
                    self.done = true;
                    if (saw_data) return error.UnexpectedEndOfStream;
                    return null;
                };

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

    fn nextLine(self: *SseParser) !?[]const u8 {
        if (self.index >= self.input.len) return null;

        const start = self.index;
        while (self.index < self.input.len and self.input[self.index] != '\n') : (self.index += 1) {}
        const end = self.index;
        if (self.index < self.input.len and self.input[self.index] == '\n') self.index += 1;
        if (end - start > max_line_len) return error.StreamTooLong;

        var line = self.input[start..end];
        if (line.len > 0 and line[line.len - 1] == '\r') line = line[0 .. line.len - 1];
        return line;
    }
};

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
