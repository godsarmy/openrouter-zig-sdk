//! HTTP request construction and transport helpers.

const std = @import("std");

const config_mod = @import("config.zig");
const options_mod = @import("options.zig");

pub const Header = options_mod.Header;

pub const Error = error{
    InvalidPath,
    OptionsInvalid,
    OutOfMemory,
};

pub const HttpRequest = struct {
    method: std.http.Method,
    path: []const u8,
    query: ?[]const u8 = null,
    body: ?[]const u8 = null,
    accept: []const u8 = "application/json",
    content_type: ?[]const u8 = "application/json",
};

pub const PreparedRequest = struct {
    arena: std.heap.ArenaAllocator,
    method: std.http.Method,
    url: []const u8,
    headers: []const Header,
    body: ?[]const u8,

    pub fn deinit(self: *PreparedRequest) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

pub const HttpResponse = struct {
    allocator: std.mem.Allocator,
    status: std.http.Status,
    body: []u8,
    content_type: ?[]const u8 = null,
    request_id: ?[]const u8 = null,
    rate_limit_remaining: ?[]const u8 = null,
    rate_limit_reset: ?[]const u8 = null,

    pub fn deinit(self: *HttpResponse) void {
        self.allocator.free(self.body);
        if (self.content_type) |value| self.allocator.free(value);
        if (self.request_id) |value| self.allocator.free(value);
        if (self.rate_limit_remaining) |value| self.allocator.free(value);
        if (self.rate_limit_reset) |value| self.allocator.free(value);
        self.* = undefined;
    }
};

const ResponseMetadata = struct {
    content_type: ?[]const u8 = null,
    request_id: ?[]const u8 = null,
    rate_limit_remaining: ?[]const u8 = null,
    rate_limit_reset: ?[]const u8 = null,

    fn deinit(self: *ResponseMetadata, allocator: std.mem.Allocator) void {
        if (self.content_type) |value| allocator.free(value);
        if (self.request_id) |value| allocator.free(value);
        if (self.rate_limit_remaining) |value| allocator.free(value);
        if (self.rate_limit_reset) |value| allocator.free(value);
        self.* = undefined;
    }
};

pub fn prepareRequest(
    allocator: std.mem.Allocator,
    config: config_mod.Config,
    request: HttpRequest,
    request_options: options_mod.RequestOptions,
) Error!PreparedRequest {
    if (request.path.len == 0 or request.path[0] != '/') return error.InvalidPath;

    _ = options_mod.merge(config, request_options) catch return error.OptionsInvalid;

    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const arena_allocator = arena.allocator();

    const url = try buildUrl(arena_allocator, config.base_url, request.path, request.query);
    const headers = try buildHeaders(arena_allocator, config, request, request_options.extra_headers);

    return .{
        .arena = arena,
        .method = request.method,
        .url = url,
        .headers = headers,
        .body = request.body,
    };
}

pub fn execute(
    allocator: std.mem.Allocator,
    client: *std.http.Client,
    prepared: PreparedRequest,
) !HttpResponse {
    var response_body: std.Io.Writer.Allocating = .init(allocator);
    errdefer response_body.deinit();

    const std_headers = try allocator.alloc(std.http.Header, prepared.headers.len);
    defer allocator.free(std_headers);
    for (prepared.headers, std_headers) |header, *std_header| {
        std_header.* = .{ .name = header.name, .value = header.value };
    }

    const uri = try std.Uri.parse(prepared.url);
    const redirect_behavior: std.http.Client.Request.RedirectBehavior = if (prepared.body == null) @enumFromInt(3) else .unhandled;
    var request = try std.http.Client.request(client, prepared.method, uri, .{
        .extra_headers = std_headers,
        .redirect_behavior = redirect_behavior,
    });
    defer request.deinit();

    if (prepared.body) |body| {
        request.transfer_encoding = .{ .content_length = body.len };
        var request_body = try request.sendBodyUnflushed(&.{});
        try request_body.writer.writeAll(body);
        try request_body.end();
        try request.connection.?.flush();
    } else {
        try request.sendBodiless();
    }

    const redirect_buffer: []u8 = if (redirect_behavior == .unhandled) &.{} else try allocator.alloc(u8, 8 * 1024);
    defer if (redirect_buffer.len > 0) allocator.free(redirect_buffer);

    var response = try request.receiveHead(redirect_buffer);
    var metadata = try responseMetadataFromHead(allocator, response.head);
    errdefer metadata.deinit(allocator);

    const decompress_buffer = try responseDecompressBuffer(allocator, response.head.content_encoding);
    defer if (decompress_buffer.len > 0) allocator.free(decompress_buffer);

    var transfer_buffer: [64]u8 = undefined;
    var decompress: std.http.Decompress = undefined;
    const reader = response.readerDecompressing(&transfer_buffer, &decompress, decompress_buffer);

    _ = reader.streamRemaining(&response_body.writer) catch |err| switch (err) {
        error.ReadFailed => return response.bodyErr().?,
        else => |e| return e,
    };

    return .{
        .allocator = allocator,
        .status = response.head.status,
        .body = try response_body.toOwnedSlice(),
        .content_type = metadata.content_type,
        .request_id = metadata.request_id,
        .rate_limit_remaining = metadata.rate_limit_remaining,
        .rate_limit_reset = metadata.rate_limit_reset,
    };
}

pub const FakeTransport = struct {
    status: std.http.Status = .ok,
    body: []const u8 = "",
    headers: []const Header = &.{},

    pub fn execute(self: FakeTransport, allocator: std.mem.Allocator, prepared: PreparedRequest) !HttpResponse {
        _ = prepared;
        var metadata = try responseMetadataFromHeaders(allocator, self.headers);
        errdefer metadata.deinit(allocator);

        return .{
            .allocator = allocator,
            .status = self.status,
            .body = try allocator.dupe(u8, self.body),
            .content_type = metadata.content_type,
            .request_id = metadata.request_id,
            .rate_limit_remaining = metadata.rate_limit_remaining,
            .rate_limit_reset = metadata.rate_limit_reset,
        };
    }
};

fn responseDecompressBuffer(allocator: std.mem.Allocator, content_encoding: std.http.ContentEncoding) ![]u8 {
    return switch (content_encoding) {
        .identity => &.{},
        .zstd => try allocator.alloc(u8, std.compress.zstd.default_window_len),
        .deflate, .gzip => try allocator.alloc(u8, std.compress.flate.max_window_len),
        .compress => error.UnsupportedCompressionMethod,
    };
}

fn responseMetadataFromHead(allocator: std.mem.Allocator, head: std.http.Client.Response.Head) !ResponseMetadata {
    var metadata: ResponseMetadata = .{};
    errdefer metadata.deinit(allocator);

    metadata.content_type = try copyOptional(allocator, head.content_type);

    var iterator = head.iterateHeaders();
    while (iterator.next()) |header| {
        try captureMetadataHeader(allocator, &metadata, header.name, header.value);
    }

    return metadata;
}

fn responseMetadataFromHeaders(allocator: std.mem.Allocator, headers: []const Header) !ResponseMetadata {
    var metadata: ResponseMetadata = .{};
    errdefer metadata.deinit(allocator);

    for (headers) |header| {
        try captureMetadataHeader(allocator, &metadata, header.name, header.value);
    }

    return metadata;
}

fn captureMetadataHeader(
    allocator: std.mem.Allocator,
    metadata: *ResponseMetadata,
    name: []const u8,
    value: []const u8,
) !void {
    if (std.ascii.eqlIgnoreCase(name, "content-type")) {
        try setOnce(allocator, &metadata.content_type, value);
    } else if (std.ascii.eqlIgnoreCase(name, "x-request-id") or std.ascii.eqlIgnoreCase(name, "request-id")) {
        try setOnce(allocator, &metadata.request_id, value);
    } else if (std.ascii.eqlIgnoreCase(name, "x-ratelimit-remaining") or std.ascii.eqlIgnoreCase(name, "ratelimit-remaining")) {
        try setOnce(allocator, &metadata.rate_limit_remaining, value);
    } else if (std.ascii.eqlIgnoreCase(name, "x-ratelimit-reset") or std.ascii.eqlIgnoreCase(name, "ratelimit-reset")) {
        try setOnce(allocator, &metadata.rate_limit_reset, value);
    }
}

fn setOnce(allocator: std.mem.Allocator, slot: *?[]const u8, value: []const u8) !void {
    if (slot.* == null) slot.* = try allocator.dupe(u8, value);
}

fn copyOptional(allocator: std.mem.Allocator, value: ?[]const u8) !?[]const u8 {
    return if (value) |payload| try allocator.dupe(u8, payload) else null;
}

pub fn buildUrl(allocator: std.mem.Allocator, base_url: []const u8, path: []const u8, query: ?[]const u8) ![]u8 {
    if (path.len == 0 or path[0] != '/') return error.InvalidPath;

    const base = std.mem.trimEnd(u8, base_url, "/");
    const separator = if (query) |q| if (q.len > 0) "?" else "" else "";
    const query_value = query orelse "";
    return std.fmt.allocPrint(allocator, "{s}{s}{s}{s}", .{ base, path, separator, query_value });
}

fn buildHeaders(
    allocator: std.mem.Allocator,
    config: config_mod.Config,
    request: HttpRequest,
    extra_headers: []const Header,
) ![]const Header {
    var headers: std.ArrayList(Header) = .empty;
    errdefer headers.deinit(allocator);

    try appendHeader(allocator, &headers, "Authorization", try std.fmt.allocPrint(allocator, "Bearer {s}", .{config.api_key}));
    try appendHeader(allocator, &headers, "User-Agent", "openrouter-zig/0.1.0");
    try appendHeader(allocator, &headers, "Accept", request.accept);
    if (request.body != null) {
        if (request.content_type) |content_type| try appendHeader(allocator, &headers, "Content-Type", content_type);
    }
    if (config.http_referer) |value| try appendHeader(allocator, &headers, "HTTP-Referer", value);
    if (config.x_title) |value| try appendHeader(allocator, &headers, "X-Title", value);

    for (extra_headers) |header| {
        try appendHeader(allocator, &headers, header.name, header.value);
    }

    return try headers.toOwnedSlice(allocator);
}

fn appendHeader(allocator: std.mem.Allocator, headers: *std.ArrayList(Header), name: []const u8, value: []const u8) !void {
    try headers.append(allocator, .{
        .name = try allocator.dupe(u8, name),
        .value = try allocator.dupe(u8, value),
    });
}

fn findHeader(headers: []const Header, name: []const u8) ?[]const u8 {
    for (headers) |header| {
        if (std.ascii.eqlIgnoreCase(header.name, name)) return header.value;
    }
    return null;
}

test "builds full URL from base path and query" {
    const url = try buildUrl(std.testing.allocator, "https://openrouter.ai/api/v1/", "/models", "limit=1");
    defer std.testing.allocator.free(url);

    try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/models?limit=1", url);
}

test "rejects relative paths without leading slash" {
    try std.testing.expectError(error.InvalidPath, buildUrl(std.testing.allocator, "https://example.com", "models", null));
}

test "prepare request adds required and optional headers" {
    var prepared = try prepareRequest(std.testing.allocator, .{
        .api_key = "secret-key",
        .http_referer = "https://example.com",
        .x_title = "openrouter-zig-test",
    }, .{
        .method = .GET,
        .path = "/models",
    }, .{});
    defer prepared.deinit();

    try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/models", prepared.url);
    try std.testing.expectEqualStrings("Bearer secret-key", findHeader(prepared.headers, "authorization").?);
    try std.testing.expectEqualStrings("openrouter-zig/0.1.0", findHeader(prepared.headers, "user-agent").?);
    try std.testing.expectEqualStrings("application/json", findHeader(prepared.headers, "accept").?);
    try std.testing.expectEqualStrings("https://example.com", findHeader(prepared.headers, "http-referer").?);
    try std.testing.expectEqualStrings("openrouter-zig-test", findHeader(prepared.headers, "x-title").?);
    try std.testing.expect(findHeader(prepared.headers, "content-type") == null);
}

test "prepare request adds content type for JSON body" {
    var prepared = try prepareRequest(std.testing.allocator, .{ .api_key = "secret-key" }, .{
        .method = .POST,
        .path = "/chat/completions",
        .body = "{}",
    }, .{});
    defer prepared.deinit();

    try std.testing.expectEqualStrings("application/json", findHeader(prepared.headers, "content-type").?);
}

test "prepare request includes extra headers" {
    var prepared = try prepareRequest(std.testing.allocator, .{ .api_key = "secret-key" }, .{
        .method = .GET,
        .path = "/models",
    }, .{
        .extra_headers = &.{.{ .name = "X-Custom", .value = "value" }},
    });
    defer prepared.deinit();

    try std.testing.expectEqualStrings("value", findHeader(prepared.headers, "x-custom").?);
}

test "prepare request rejects reserved extra headers" {
    try std.testing.expectError(error.OptionsInvalid, prepareRequest(std.testing.allocator, .{ .api_key = "secret-key" }, .{
        .method = .GET,
        .path = "/models",
    }, .{
        .extra_headers = &.{.{ .name = "Authorization", .value = "Bearer other" }},
    }));
}

test "fake transport returns owned response body" {
    var prepared = try prepareRequest(std.testing.allocator, .{ .api_key = "secret-key" }, .{
        .method = .GET,
        .path = "/models",
    }, .{});
    defer prepared.deinit();

    var response = try (FakeTransport{ .body = "{\"data\":[]}" }).execute(std.testing.allocator, prepared);
    defer response.deinit();

    try std.testing.expectEqual(std.http.Status.ok, response.status);
    try std.testing.expectEqualStrings("{\"data\":[]}", response.body);
}

test "fake transport captures response metadata headers" {
    var prepared = try prepareRequest(std.testing.allocator, .{ .api_key = "secret-key" }, .{
        .method = .GET,
        .path = "/models",
    }, .{});
    defer prepared.deinit();

    var response = try (FakeTransport{
        .headers = &.{
            .{ .name = "Content-Type", .value = "application/json; charset=utf-8" },
            .{ .name = "X-Request-ID", .value = "req_123" },
            .{ .name = "X-RateLimit-Remaining", .value = "42" },
            .{ .name = "X-RateLimit-Reset", .value = "1710000000" },
        },
    }).execute(std.testing.allocator, prepared);
    defer response.deinit();

    try std.testing.expectEqualStrings("application/json; charset=utf-8", response.content_type.?);
    try std.testing.expectEqualStrings("req_123", response.request_id.?);
    try std.testing.expectEqualStrings("42", response.rate_limit_remaining.?);
    try std.testing.expectEqualStrings("1710000000", response.rate_limit_reset.?);
}

test "response metadata captures alternate header names case insensitively" {
    const metadata = try responseMetadataFromHeaders(std.testing.allocator, &.{
        .{ .name = "request-id", .value = "req_alt" },
        .{ .name = "RateLimit-Remaining", .value = "9" },
        .{ .name = "RateLimit-Reset", .value = "60" },
    });
    var mutable_metadata = metadata;
    defer mutable_metadata.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("req_alt", mutable_metadata.request_id.?);
    try std.testing.expectEqualStrings("9", mutable_metadata.rate_limit_remaining.?);
    try std.testing.expectEqualStrings("60", mutable_metadata.rate_limit_reset.?);
}

test "prepare POST request preserves JSON body for transport" {
    var prepared = try prepareRequest(std.testing.allocator, .{ .api_key = "secret-key" }, .{
        .method = .POST,
        .path = "/chat/completions",
        .body = "{\"model\":\"test\"}",
    }, .{});
    defer prepared.deinit();

    try std.testing.expectEqual(std.http.Method.POST, prepared.method);
    try std.testing.expectEqualStrings("{\"model\":\"test\"}", prepared.body.?);
    try std.testing.expectEqualStrings("application/json", findHeader(prepared.headers, "content-type").?);
}
