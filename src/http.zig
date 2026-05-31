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

    const result = try client.fetch(.{
        .location = .{ .url = prepared.url },
        .method = prepared.method,
        .payload = prepared.body,
        .response_writer = &response_body.writer,
        .extra_headers = std_headers,
    });

    return .{
        .allocator = allocator,
        .status = result.status,
        .body = try response_body.toOwnedSlice(),
    };
}

pub const FakeTransport = struct {
    status: std.http.Status = .ok,
    body: []const u8 = "",

    pub fn execute(self: FakeTransport, allocator: std.mem.Allocator, prepared: PreparedRequest) !HttpResponse {
        _ = prepared;
        return .{
            .allocator = allocator,
            .status = self.status,
            .body = try allocator.dupe(u8, self.body),
        };
    }
};

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
    try appendHeader(allocator, &headers, "User-Agent", "openrouter-zig/0.0.0");
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
    try std.testing.expectEqualStrings("openrouter-zig/0.0.0", findHeader(prepared.headers, "user-agent").?);
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
