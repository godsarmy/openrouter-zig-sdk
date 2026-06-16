//! Shared Server-Sent Events parsing and HTTP stream state.

const std = @import("std");

const http = @import("http.zig");

const max_line_len = 64 * 1024;
const max_event_len = 1024 * 1024;

pub const State = struct {
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

    pub fn initReader(self: *State) void {
        // `std.http.Client.Response` stores a pointer to its request. Streaming
        // setup moves both values into `State`, so rebind that pointer before
        // creating the body reader; otherwise it can point at an old stack copy.
        self.rebindResponseRequest();
        self.reader = self.response.reader(&self.transfer_buffer);
    }

    fn rebindResponseRequest(self: *State) void {
        self.response.request = &self.request;
    }

    pub fn deinit(self: *State) void {
        self.request.deinit();
        self.allocator.free(self.std_headers);
        self.prepared.deinit();
        self.allocator.free(self.body);
        const allocator = self.allocator;
        self.* = undefined;
        allocator.destroy(self);
    }

    pub fn nextDataEvent(self: *State) !?[]u8 {
        if (self.done) return null;

        while (true) {
            var event_data: std.Io.Writer.Allocating = .init(self.allocator);
            defer event_data.deinit();
            var saw_data = false;

            while (true) {
                const maybe_line = self.readLineAlloc() catch |err| {
                    self.done = true;
                    return err;
                };
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
                    if (event_data.written().len > max_event_len) {
                        self.done = true;
                        return error.StreamTooLong;
                    }
                    saw_data = true;
                } else {
                    if (std.mem.indexOfScalar(u8, line, ':') == null) {
                        self.done = true;
                        return error.MalformedSse;
                    }
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
                error.ReadFailed => return self.readFailure(),
            };
            if (n == 0) return null;
            self.read_pos = 0;
            self.read_end = n;
        }

        const byte = self.read_buffer[self.read_pos];
        self.read_pos += 1;
        return byte;
    }

    fn readFailure(self: *State) error{ Canceled, UnexpectedEndOfStream } {
        const connection = self.request.connection orelse return error.UnexpectedEndOfStream;
        const read_error = connection.getReadError() orelse return error.UnexpectedEndOfStream;
        return switch (read_error) {
            error.Canceled => error.Canceled,
            else => error.UnexpectedEndOfStream,
        };
    }
};

pub const Parser = struct {
    allocator: std.mem.Allocator,
    input: []const u8,
    index: usize = 0,
    done: bool = false,

    pub fn nextData(self: *Parser) !?[]u8 {
        if (self.done) return null;

        while (true) {
            var event_data: std.Io.Writer.Allocating = .init(self.allocator);
            defer event_data.deinit();
            var saw_data = false;

            while (true) {
                const maybe_line = self.nextLine() catch |err| {
                    self.done = true;
                    return err;
                };
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
                    if (event_data.written().len > max_event_len) {
                        self.done = true;
                        return error.StreamTooLong;
                    }
                    saw_data = true;
                } else {
                    if (std.mem.indexOfScalar(u8, line, ':') == null) {
                        self.done = true;
                        return error.MalformedSse;
                    }
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

    fn nextLine(self: *Parser) !?[]const u8 {
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
    var parser: Parser = .{
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
    var parser: Parser = .{
        .allocator = std.testing.allocator,
        .input = "data: hello\ndata: world\n\n",
    };

    const data = (try parser.nextData()).?;
    defer std.testing.allocator.free(data);
    try std.testing.expectEqualStrings("hello\nworld", data);
}

test "SSE parser handles CRLF and done" {
    var parser: Parser = .{
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
    var parser: Parser = .{
        .allocator = std.testing.allocator,
        .input = "event: message\nid: 1\nretry: 100\next: future\ndata: hello\n\n",
    };

    const data = (try parser.nextData()).?;
    defer std.testing.allocator.free(data);
    try std.testing.expectEqualStrings("hello", data);
}

test "SSE parser accepts empty data line" {
    var parser: Parser = .{
        .allocator = std.testing.allocator,
        .input = "data\n\n",
    };

    const data = (try parser.nextData()).?;
    defer std.testing.allocator.free(data);
    try std.testing.expectEqualStrings("", data);
}

test "SSE parser rejects malformed field" {
    var parser: Parser = .{
        .allocator = std.testing.allocator,
        .input = "badfield\n\n",
    };

    try std.testing.expectError(error.MalformedSse, parser.nextData());
    try std.testing.expectEqual(null, try parser.nextData());
}

test "SSE parser marks done after EOF mid-event" {
    var parser: Parser = .{
        .allocator = std.testing.allocator,
        .input = "data: partial",
    };

    try std.testing.expectError(error.UnexpectedEndOfStream, parser.nextData());
    try std.testing.expectEqual(null, try parser.nextData());
}

test "SSE parser marks done after line too long" {
    const long_line = try std.testing.allocator.alloc(u8, max_line_len + 1);
    defer std.testing.allocator.free(long_line);
    @memset(long_line, 'x');

    var input = std.Io.Writer.Allocating.init(std.testing.allocator);
    defer input.deinit();
    try input.writer.writeAll(long_line);
    try input.writer.writeAll("\n\n");

    var parser: Parser = .{
        .allocator = std.testing.allocator,
        .input = input.written(),
    };

    try std.testing.expectError(error.StreamTooLong, parser.nextData());
    try std.testing.expectEqual(null, try parser.nextData());
}

test "SSE state rebinds response request after move" {
    var state: State = undefined;

    state.rebindResponseRequest();

    try std.testing.expectEqual(&state.request, state.response.request);
}
