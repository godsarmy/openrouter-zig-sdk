//! Preset-based inference API.

const std = @import("std");

const chat_mod = @import("chat.zig");
const config_mod = @import("config.zig");
const errors = @import("errors.zig");
const http = @import("http.zig");
const json = @import("json.zig");
const messages_mod = @import("messages.zig");
const options_mod = @import("options.zig");
const query_mod = @import("query.zig");
const responses_mod = @import("responses.zig");

pub const ListRequest = struct {
    offset: ?u64 = null,
    limit: ?u64 = null,
};

pub const GetRequest = struct {
    slug: []const u8,
};

pub const VersionsListRequest = struct {
    slug: []const u8,
    offset: ?u64 = null,
    limit: ?u64 = null,
};

pub const VersionGetRequest = struct {
    slug: []const u8,
    version: []const u8,
};

pub const ChatCompletionsCreateRequest = struct {
    slug: []const u8,
    request: chat_mod.CompletionRequest,
};

pub const MessagesCreateRequest = struct {
    slug: []const u8,
    request: messages_mod.CreateRequest,
};

pub const ResponsesCreateRequest = struct {
    slug: []const u8,
    request: responses_mod.CreateRequest,
};

pub const PresetCreateResponse = struct {
    arena: std.heap.ArenaAllocator,
    response_metadata: http.ResponseMetadata = .{},
    data: Preset,

    pub fn deinit(self: *PresetCreateResponse) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

pub const ListResponse = struct {
    arena: std.heap.ArenaAllocator,
    data: []Preset,
    total_count: u64,

    pub fn deinit(self: *ListResponse) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

pub const GetResponse = struct {
    arena: std.heap.ArenaAllocator,
    data: Preset,

    pub fn deinit(self: *GetResponse) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

pub const VersionsListResponse = struct {
    arena: std.heap.ArenaAllocator,
    data: []?PresetVersion,
    total_count: u64,

    pub fn deinit(self: *VersionsListResponse) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

pub const VersionGetResponse = struct {
    arena: std.heap.ArenaAllocator,
    data: ?PresetVersion,

    pub fn deinit(self: *VersionGetResponse) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

pub const ChatCompletionsCreateResponse = PresetCreateResponse;
pub const MessagesCreateResponse = PresetCreateResponse;
pub const ResponsesCreateResponse = PresetCreateResponse;

pub const Preset = struct {
    id: []const u8,
    name: ?[]const u8 = null,
    description: ?[]const u8 = null,
    slug: []const u8,
    status: ?[]const u8 = null,
    designated_version_id: ?[]const u8 = null,
    creator_user_id: ?[]const u8 = null,
    status_updated_at: ?[]const u8 = null,
    workspace_id: ?[]const u8 = null,
    created_at: ?[]const u8 = null,
    updated_at: ?[]const u8 = null,
    designated_version: ?PresetVersion = null,
};

pub const PresetVersion = struct {
    id: []const u8,
    version: ?i64 = null,
    preset_id: ?[]const u8 = null,
    creator_id: ?[]const u8 = null,
    system_prompt: ?[]const u8 = null,
    config: ?std.json.Value = null,
    created_at: ?[]const u8 = null,
    updated_at: ?[]const u8 = null,
};

const WirePresetCreateResponse = struct {
    data: Preset,
};

const WireListResponse = struct {
    data: []Preset,
    total_count: u64,
};

const WireGetResponse = struct {
    data: Preset,
};

const WireVersionsListResponse = struct {
    data: []?PresetVersion,
    total_count: u64,
};

const WireVersionGetResponse = struct {
    data: ?PresetVersion,
};

pub fn list(client: anytype, request: ListRequest, request_options: options_mod.RequestOptions) !ListResponse {
    return listWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, request, request_options);
}

pub fn get(client: anytype, request: GetRequest, request_options: options_mod.RequestOptions) !GetResponse {
    return getWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, request, request_options);
}

pub fn listVersions(client: anytype, request: VersionsListRequest, request_options: options_mod.RequestOptions) !VersionsListResponse {
    return listVersionsWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, request, request_options);
}

pub fn getVersion(client: anytype, request: VersionGetRequest, request_options: options_mod.RequestOptions) !VersionGetResponse {
    return getVersionWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, request, request_options);
}

pub fn createChatCompletion(client: anytype, request: ChatCompletionsCreateRequest, request_options: options_mod.RequestOptions) !ChatCompletionsCreateResponse {
    return createChatCompletionWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, request, request_options);
}

pub fn listWithTransport(
    allocator: std.mem.Allocator,
    config: config_mod.Config,
    transport: anytype,
    request: ListRequest,
    request_options: options_mod.RequestOptions,
) !ListResponse {
    const query = try listQueryString(allocator, request);
    defer allocator.free(query);

    var prepared = try http.prepareRequest(allocator, config, .{
        .method = .GET,
        .path = "/presets",
        .query = query,
    }, request_options);
    defer prepared.deinit();

    var response = try transport.execute(allocator, prepared);
    defer response.deinit();

    return parseListResponse(allocator, response);
}

pub fn getWithTransport(
    allocator: std.mem.Allocator,
    config: config_mod.Config,
    transport: anytype,
    request: GetRequest,
    request_options: options_mod.RequestOptions,
) !GetResponse {
    const path = try presetPath(allocator, request.slug);
    defer allocator.free(path);

    var prepared = try http.prepareRequest(allocator, config, .{
        .method = .GET,
        .path = path,
    }, request_options);
    defer prepared.deinit();

    var response = try transport.execute(allocator, prepared);
    defer response.deinit();

    return parseGetResponse(allocator, response);
}

pub fn listVersionsWithTransport(
    allocator: std.mem.Allocator,
    config: config_mod.Config,
    transport: anytype,
    request: VersionsListRequest,
    request_options: options_mod.RequestOptions,
) !VersionsListResponse {
    const path = try presetEndpointPath(allocator, request.slug, "/versions");
    defer allocator.free(path);
    const query = try versionsListQueryString(allocator, request);
    defer allocator.free(query);

    var prepared = try http.prepareRequest(allocator, config, .{
        .method = .GET,
        .path = path,
        .query = query,
    }, request_options);
    defer prepared.deinit();

    var response = try transport.execute(allocator, prepared);
    defer response.deinit();

    return parseVersionsListResponse(allocator, response);
}

pub fn getVersionWithTransport(
    allocator: std.mem.Allocator,
    config: config_mod.Config,
    transport: anytype,
    request: VersionGetRequest,
    request_options: options_mod.RequestOptions,
) !VersionGetResponse {
    const path = try versionPath(allocator, request);
    defer allocator.free(path);

    var prepared = try http.prepareRequest(allocator, config, .{
        .method = .GET,
        .path = path,
    }, request_options);
    defer prepared.deinit();

    var response = try transport.execute(allocator, prepared);
    defer response.deinit();

    return parseVersionGetResponse(allocator, response);
}

pub fn createMessage(client: anytype, request: MessagesCreateRequest, request_options: options_mod.RequestOptions) !MessagesCreateResponse {
    return createMessageWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, request, request_options);
}

pub fn createResponse(client: anytype, request: ResponsesCreateRequest, request_options: options_mod.RequestOptions) !ResponsesCreateResponse {
    return createResponseWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, request, request_options);
}

pub fn createChatCompletionWithTransport(
    allocator: std.mem.Allocator,
    config: config_mod.Config,
    transport: anytype,
    request: ChatCompletionsCreateRequest,
    request_options: options_mod.RequestOptions,
) !ChatCompletionsCreateResponse {
    const body = try json.stringifyRequest(allocator, forceNonStreaming(request.request));
    defer allocator.free(body);
    const path = try chatCompletionsPath(allocator, request.slug);
    defer allocator.free(path);

    var prepared = try http.prepareRequest(allocator, config, .{
        .method = .POST,
        .path = path,
        .body = body,
    }, request_options);
    defer prepared.deinit();

    var response = try transport.execute(allocator, prepared);
    defer response.deinit();

    return parsePresetCreateResponse(allocator, response);
}

pub fn parseChatCompletionsCreateResponse(allocator: std.mem.Allocator, response: http.HttpResponse) !ChatCompletionsCreateResponse {
    return parsePresetCreateResponse(allocator, response);
}

pub fn parsePresetCreateResponse(allocator: std.mem.Allocator, response: http.HttpResponse) !PresetCreateResponse {
    if (errors.isErrorStatus(@intFromEnum(response.status))) return error.ApiError;

    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const arena_allocator = arena.allocator();

    const owned_body = try arena_allocator.dupe(u8, response.body);
    const parsed = try json.parseResponseLeaky(WirePresetCreateResponse, arena_allocator, owned_body);
    return .{
        .arena = arena,
        .response_metadata = try http.ResponseMetadata.fromHttpResponse(arena_allocator, response),
        .data = parsed.data,
    };
}

pub fn parseListResponse(allocator: std.mem.Allocator, response: http.HttpResponse) !ListResponse {
    if (errors.isErrorStatus(@intFromEnum(response.status))) return error.ApiError;

    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const arena_allocator = arena.allocator();

    const owned_body = try arena_allocator.dupe(u8, response.body);
    const parsed = try json.parseResponseLeaky(WireListResponse, arena_allocator, owned_body);
    return .{
        .arena = arena,
        .data = parsed.data,
        .total_count = parsed.total_count,
    };
}

pub fn parseGetResponse(allocator: std.mem.Allocator, response: http.HttpResponse) !GetResponse {
    if (errors.isErrorStatus(@intFromEnum(response.status))) return error.ApiError;

    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const arena_allocator = arena.allocator();

    const owned_body = try arena_allocator.dupe(u8, response.body);
    const parsed = try json.parseResponseLeaky(WireGetResponse, arena_allocator, owned_body);
    return .{
        .arena = arena,
        .data = parsed.data,
    };
}

pub fn parseVersionsListResponse(allocator: std.mem.Allocator, response: http.HttpResponse) !VersionsListResponse {
    if (errors.isErrorStatus(@intFromEnum(response.status))) return error.ApiError;

    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const arena_allocator = arena.allocator();

    const owned_body = try arena_allocator.dupe(u8, response.body);
    const parsed = try json.parseResponseLeaky(WireVersionsListResponse, arena_allocator, owned_body);
    return .{
        .arena = arena,
        .data = parsed.data,
        .total_count = parsed.total_count,
    };
}

pub fn parseVersionGetResponse(allocator: std.mem.Allocator, response: http.HttpResponse) !VersionGetResponse {
    if (errors.isErrorStatus(@intFromEnum(response.status))) return error.ApiError;

    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const arena_allocator = arena.allocator();

    const owned_body = try arena_allocator.dupe(u8, response.body);
    const parsed = try json.parseResponseLeaky(WireVersionGetResponse, arena_allocator, owned_body);
    return .{
        .arena = arena,
        .data = parsed.data,
    };
}

pub fn createMessageWithTransport(
    allocator: std.mem.Allocator,
    config: config_mod.Config,
    transport: anytype,
    request: MessagesCreateRequest,
    request_options: options_mod.RequestOptions,
) !MessagesCreateResponse {
    const body = try json.stringifyRequest(allocator, request.request);
    defer allocator.free(body);
    const path = try messagesPath(allocator, request.slug);
    defer allocator.free(path);

    var prepared = try http.prepareRequest(allocator, config, .{
        .method = .POST,
        .path = path,
        .body = body,
    }, request_options);
    defer prepared.deinit();

    var response = try transport.execute(allocator, prepared);
    defer response.deinit();

    return parsePresetCreateResponse(allocator, response);
}

pub fn createResponseWithTransport(
    allocator: std.mem.Allocator,
    config: config_mod.Config,
    transport: anytype,
    request: ResponsesCreateRequest,
    request_options: options_mod.RequestOptions,
) !ResponsesCreateResponse {
    const body = try json.stringifyRequest(allocator, request.request);
    defer allocator.free(body);
    const path = try responsesPath(allocator, request.slug);
    defer allocator.free(path);

    var prepared = try http.prepareRequest(allocator, config, .{
        .method = .POST,
        .path = path,
        .body = body,
    }, request_options);
    defer prepared.deinit();

    var response = try transport.execute(allocator, prepared);
    defer response.deinit();

    return parsePresetCreateResponse(allocator, response);
}

fn forceNonStreaming(request: chat_mod.CompletionRequest) chat_mod.CompletionRequest {
    var copy = request;
    copy.stream = false;
    return copy;
}

fn chatCompletionsPath(allocator: std.mem.Allocator, slug: []const u8) ![]u8 {
    var path: std.ArrayList(u8) = .empty;
    errdefer path.deinit(allocator);

    try path.appendSlice(allocator, "/presets/");
    try appendPathSegment(allocator, &path, slug);
    try path.appendSlice(allocator, "/chat/completions");

    return path.toOwnedSlice(allocator);
}

fn messagesPath(allocator: std.mem.Allocator, slug: []const u8) ![]u8 {
    return presetEndpointPath(allocator, slug, "/messages");
}

fn responsesPath(allocator: std.mem.Allocator, slug: []const u8) ![]u8 {
    return presetEndpointPath(allocator, slug, "/responses");
}

fn presetPath(allocator: std.mem.Allocator, slug: []const u8) ![]u8 {
    return presetEndpointPath(allocator, slug, "");
}

fn versionPath(allocator: std.mem.Allocator, request: VersionGetRequest) ![]u8 {
    var path: std.ArrayList(u8) = .empty;
    errdefer path.deinit(allocator);

    try path.appendSlice(allocator, "/presets/");
    try appendPathSegment(allocator, &path, request.slug);
    try path.appendSlice(allocator, "/versions/");
    try appendPathSegment(allocator, &path, request.version);

    return path.toOwnedSlice(allocator);
}

fn listQueryString(allocator: std.mem.Allocator, request: ListRequest) ![]u8 {
    return paginationQueryString(allocator, request.offset, request.limit);
}

fn versionsListQueryString(allocator: std.mem.Allocator, request: VersionsListRequest) ![]u8 {
    return paginationQueryString(allocator, request.offset, request.limit);
}

fn paginationQueryString(allocator: std.mem.Allocator, offset: ?u64, limit: ?u64) ![]u8 {
    const offset_value = if (offset) |value| try std.fmt.allocPrint(allocator, "{}", .{value}) else null;
    defer if (offset_value) |value| allocator.free(value);
    const limit_value = if (limit) |value| try std.fmt.allocPrint(allocator, "{}", .{value}) else null;
    defer if (limit_value) |value| allocator.free(value);

    return query_mod.build(allocator, &.{
        .{ .name = "offset", .value = offset_value },
        .{ .name = "limit", .value = limit_value },
    });
}

fn presetEndpointPath(allocator: std.mem.Allocator, slug: []const u8, suffix: []const u8) ![]u8 {
    var path: std.ArrayList(u8) = .empty;
    errdefer path.deinit(allocator);

    try path.appendSlice(allocator, "/presets/");
    try appendPathSegment(allocator, &path, slug);
    try path.appendSlice(allocator, suffix);

    return path.toOwnedSlice(allocator);
}

fn appendPathSegment(allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: []const u8) !void {
    const hex = "0123456789ABCDEF";
    for (value) |byte| {
        if (std.ascii.isAlphanumeric(byte) or byte == '-' or byte == '_' or byte == '.' or byte == '~') {
            try output.append(allocator, byte);
        } else {
            try output.appendSlice(allocator, &.{ '%', hex[byte >> 4], hex[byte & 0x0F] });
        }
    }
}

test "presets list parses response and total count" {
    const body =
        \\{
        \\  "data": [
        \\    {
        \\      "id": "preset_123",
        \\      "name": "Email Copywriter",
        \\      "description": "Writes email copy",
        \\      "slug": "email-copywriter",
        \\      "status": "active",
        \\      "creator_user_id": null,
        \\      "designated_version_id": "version_123",
        \\      "status_updated_at": null,
        \\      "workspace_id": null,
        \\      "created_at": "2026-04-20T10:00:00Z",
        \\      "updated_at": "2026-04-20T10:00:00Z",
        \\      "unknown": true
        \\    }
        \\  ],
        \\  "total_count": 1
        \\}
    ;

    var result = try listWithTransport(std.testing.allocator, .{ .api_key = "test-key" }, http.FakeTransport{ .body = body }, .{}, .{});
    defer result.deinit();

    try std.testing.expectEqual(@as(usize, 1), result.data.len);
    try std.testing.expectEqual(@as(u64, 1), result.total_count);
    try std.testing.expectEqualStrings("preset_123", result.data[0].id);
    try std.testing.expectEqualStrings("email-copywriter", result.data[0].slug);
}

test "presets list sends GET /presets with pagination" {
    const query = try listQueryString(std.testing.allocator, .{ .offset = 10, .limit = 25 });
    defer std.testing.allocator.free(query);

    var prepared = try http.prepareRequest(std.testing.allocator, .{ .api_key = "test-key" }, .{
        .method = .GET,
        .path = "/presets",
        .query = query,
    }, .{});
    defer prepared.deinit();

    try std.testing.expectEqual(std.http.Method.GET, prepared.method);
    try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/presets?offset=10&limit=25", prepared.url);
}

test "presets get parses designated version" {
    const body =
        \\{
        \\  "data": {
        \\    "id": "preset_123",
        \\    "name": "Email Copywriter",
        \\    "slug": "email-copywriter",
        \\    "status": "active",
        \\    "designated_version": {
        \\      "id": "version_123",
        \\      "preset_id": "preset_123",
        \\      "creator_id": "user_123",
        \\      "version": 1,
        \\      "system_prompt": "You are helpful.",
        \\      "config": { "model": "openai/gpt-4o-mini" },
        \\      "created_at": "2026-04-20T10:00:00Z",
        \\      "updated_at": "2026-04-20T10:00:00Z"
        \\    }
        \\  }
        \\}
    ;

    var result = try getWithTransport(std.testing.allocator, .{ .api_key = "test-key" }, http.FakeTransport{ .body = body }, .{ .slug = "email-copywriter" }, .{});
    defer result.deinit();

    try std.testing.expectEqualStrings("email-copywriter", result.data.slug);
    try std.testing.expectEqualStrings("version_123", result.data.designated_version.?.id);
    try std.testing.expectEqualStrings("preset_123", result.data.designated_version.?.preset_id.?);
}

test "presets get sends escaped GET /presets/{slug}" {
    const path = try presetPath(std.testing.allocator, "email copywriter");
    defer std.testing.allocator.free(path);

    var prepared = try http.prepareRequest(std.testing.allocator, .{ .api_key = "test-key" }, .{
        .method = .GET,
        .path = path,
    }, .{});
    defer prepared.deinit();

    try std.testing.expectEqual(std.http.Method.GET, prepared.method);
    try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/presets/email%20copywriter", prepared.url);
}

test "preset versions list parses nullable versions" {
    const body =
        \\{
        \\  "data": [
        \\    {
        \\      "id": "version_123",
        \\      "preset_id": "preset_123",
        \\      "creator_id": "user_123",
        \\      "version": 1,
        \\      "system_prompt": null,
        \\      "config": { "temperature": 0.7 },
        \\      "created_at": "2026-04-20T10:00:00Z",
        \\      "updated_at": "2026-04-20T10:00:00Z"
        \\    },
        \\    null
        \\  ],
        \\  "total_count": 2
        \\}
    ;

    var result = try listVersionsWithTransport(std.testing.allocator, .{ .api_key = "test-key" }, http.FakeTransport{ .body = body }, .{ .slug = "email-copywriter" }, .{});
    defer result.deinit();

    try std.testing.expectEqual(@as(usize, 2), result.data.len);
    try std.testing.expectEqual(@as(u64, 2), result.total_count);
    try std.testing.expectEqualStrings("version_123", result.data[0].?.id);
    try std.testing.expect(result.data[1] == null);
}

test "preset versions list sends GET /presets/{slug}/versions with pagination" {
    const path = try presetEndpointPath(std.testing.allocator, "email copywriter", "/versions");
    defer std.testing.allocator.free(path);
    const query = try versionsListQueryString(std.testing.allocator, .{ .slug = "email copywriter", .offset = 5, .limit = 10 });
    defer std.testing.allocator.free(query);

    var prepared = try http.prepareRequest(std.testing.allocator, .{ .api_key = "test-key" }, .{
        .method = .GET,
        .path = path,
        .query = query,
    }, .{});
    defer prepared.deinit();

    try std.testing.expectEqual(std.http.Method.GET, prepared.method);
    try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/presets/email%20copywriter/versions?offset=5&limit=10", prepared.url);
}

test "preset version get parses nullable version" {
    var result = try getVersionWithTransport(std.testing.allocator, .{ .api_key = "test-key" }, http.FakeTransport{ .body = "{\"data\":null}" }, .{
        .slug = "email-copywriter",
        .version = "1",
    }, .{});
    defer result.deinit();

    try std.testing.expect(result.data == null);
}

test "preset version get sends escaped GET /presets/{slug}/versions/{version}" {
    const path = try versionPath(std.testing.allocator, .{ .slug = "email copywriter", .version = "v/1" });
    defer std.testing.allocator.free(path);

    var prepared = try http.prepareRequest(std.testing.allocator, .{ .api_key = "test-key" }, .{
        .method = .GET,
        .path = path,
    }, .{});
    defer prepared.deinit();

    try std.testing.expectEqual(std.http.Method.GET, prepared.method);
    try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/presets/email%20copywriter/versions/v%2F1", prepared.url);
}

test "preset reads map error status to ApiError" {
    try std.testing.expectError(error.ApiError, listWithTransport(
        std.testing.allocator,
        .{ .api_key = "test-key" },
        http.FakeTransport{ .status = .forbidden, .body = "{\"error\":{\"message\":\"forbidden\"}}" },
        .{},
        .{},
    ));
}

test "preset chat completions create serializes chat request" {
    const body = try json.stringifyRequest(std.testing.allocator, forceNonStreaming(.{
        .model = "openai/gpt-4o-mini",
        .messages = &.{.{ .role = .user, .content = .{ .text = "Write a marketing email." } }},
        .temperature = 0.7,
        .stream = true,
    }));
    defer std.testing.allocator.free(body);

    try std.testing.expect(std.mem.indexOf(u8, body, "\"model\":\"openai/gpt-4o-mini\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"content\":\"Write a marketing email.\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"stream\":false") != null);
}

test "preset chat completions create parses response" {
    const body =
        \\{
        \\  "data": {
        \\    "id": "preset_123",
        \\    "name": "Email Copywriter",
        \\    "slug": "email-copywriter",
        \\    "status": "active",
        \\    "designated_version_id": "version_123",
        \\    "created_at": "2026-04-20T10:00:00Z",
        \\    "updated_at": "2026-04-20T10:00:00Z",
        \\    "designated_version": {
        \\      "id": "version_123",
        \\      "version": 1,
        \\      "system_prompt": "You are a helpful assistant.",
        \\      "config": { "model": "openai/gpt-4o-mini", "temperature": 0.7 },
        \\      "created_at": "2026-04-20T10:00:00Z",
        \\      "updated_at": "2026-04-20T10:00:00Z"
        \\    },
        \\    "unknown": true
        \\  }
        \\}
    ;

    var result = try createChatCompletionWithTransport(std.testing.allocator, .{ .api_key = "test-key" }, http.FakeTransport{ .body = body }, .{
        .slug = "email-copywriter",
        .request = .{
            .model = "openai/gpt-4o-mini",
            .messages = &.{.{ .role = .user, .content = .{ .text = "Write a marketing email." } }},
        },
    }, .{});
    defer result.deinit();

    try std.testing.expectEqualStrings("preset_123", result.data.id);
    try std.testing.expectEqualStrings("email-copywriter", result.data.slug);
    try std.testing.expectEqualStrings("version_123", result.data.designated_version.?.id);
    try std.testing.expectEqual(@as(?i64, 1), result.data.designated_version.?.version);
}

test "preset chat completions create sends POST /presets/{slug}/chat/completions" {
    const path = try chatCompletionsPath(std.testing.allocator, "email copywriter");
    defer std.testing.allocator.free(path);

    var prepared = try http.prepareRequest(std.testing.allocator, .{ .api_key = "test-key" }, .{
        .method = .POST,
        .path = path,
        .body = "{}",
    }, .{});
    defer prepared.deinit();

    try std.testing.expectEqual(std.http.Method.POST, prepared.method);
    try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/presets/email%20copywriter/chat/completions", prepared.url);
}

test "preset chat completions create maps error status to ApiError" {
    try std.testing.expectError(error.ApiError, createChatCompletionWithTransport(
        std.testing.allocator,
        .{ .api_key = "test-key" },
        http.FakeTransport{ .status = .bad_request, .body = "{\"error\":{\"message\":\"bad preset\"}}" },
        .{
            .slug = "email-copywriter",
            .request = .{
                .model = "openai/gpt-4o-mini",
                .messages = &.{.{ .role = .user, .content = .{ .text = "Hello" } }},
            },
        },
        .{},
    ));
}

test "preset messages create serializes messages request" {
    const body = try json.stringifyRequest(std.testing.allocator, (MessagesCreateRequest{
        .slug = "anthropic-preset",
        .request = .{
            .model = "anthropic/claude-3.5-sonnet",
            .messages = &.{.{ .role = .user, .content = .{ .text = "Write a haiku." } }},
            .max_tokens = 128,
        },
    }).request);
    defer std.testing.allocator.free(body);

    try std.testing.expect(std.mem.indexOf(u8, body, "\"model\":\"anthropic/claude-3.5-sonnet\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"content\":\"Write a haiku.\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"max_tokens\":128") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"slug\"") == null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"stream\"") == null);
}

test "preset messages create parses response" {
    const body =
        \\{
        \\  "data": {
        \\    "id": "preset_msg_123",
        \\    "name": "Anthropic Preset",
        \\    "slug": "anthropic-preset",
        \\    "status": "active",
        \\    "designated_version_id": "version_msg_123",
        \\    "designated_version": {
        \\      "id": "version_msg_123",
        \\      "version": 2,
        \\      "system_prompt": "You are concise."
        \\    }
        \\  }
        \\}
    ;

    var result = try createMessageWithTransport(std.testing.allocator, .{ .api_key = "test-key" }, http.FakeTransport{ .body = body }, .{
        .slug = "anthropic-preset",
        .request = .{
            .model = "anthropic/claude-3.5-sonnet",
            .messages = &.{.{ .role = .user, .content = .{ .text = "Hello" } }},
        },
    }, .{});
    defer result.deinit();

    try std.testing.expectEqualStrings("preset_msg_123", result.data.id);
    try std.testing.expectEqualStrings("anthropic-preset", result.data.slug);
    try std.testing.expectEqualStrings("version_msg_123", result.data.designated_version.?.id);
}

test "preset messages create sends POST /presets/{slug}/messages" {
    const path = try messagesPath(std.testing.allocator, "anthropic preset");
    defer std.testing.allocator.free(path);

    var prepared = try http.prepareRequest(std.testing.allocator, .{ .api_key = "test-key" }, .{
        .method = .POST,
        .path = path,
        .body = "{}",
    }, .{});
    defer prepared.deinit();

    try std.testing.expectEqual(std.http.Method.POST, prepared.method);
    try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/presets/anthropic%20preset/messages", prepared.url);
}

test "preset messages create maps error status to ApiError" {
    try std.testing.expectError(error.ApiError, createMessageWithTransport(
        std.testing.allocator,
        .{ .api_key = "test-key" },
        http.FakeTransport{ .status = .bad_request, .body = "{\"error\":{\"message\":\"bad preset\"}}" },
        .{
            .slug = "anthropic-preset",
            .request = .{
                .model = "anthropic/claude-3.5-sonnet",
                .messages = &.{.{ .role = .user, .content = .{ .text = "Hello" } }},
            },
        },
        .{},
    ));
}

test "preset responses create serializes responses request" {
    const body = try json.stringifyRequest(std.testing.allocator, (ResponsesCreateRequest{
        .slug = "openai-preset",
        .request = .{
            .model = "openai/o4-mini",
            .input = .{ .text = "Summarize this." },
            .max_output_tokens = 256,
        },
    }).request);
    defer std.testing.allocator.free(body);

    try std.testing.expect(std.mem.indexOf(u8, body, "\"model\":\"openai/o4-mini\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"input\":\"Summarize this.\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"max_output_tokens\":256") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"slug\"") == null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"stream\"") == null);
}

test "preset responses create parses response" {
    const body =
        \\{
        \\  "data": {
        \\    "id": "preset_resp_123",
        \\    "name": "OpenAI Preset",
        \\    "slug": "openai-preset",
        \\    "status": "active",
        \\    "designated_version_id": "version_resp_123",
        \\    "designated_version": {
        \\      "id": "version_resp_123",
        \\      "version": 3,
        \\      "system_prompt": "You are precise."
        \\    }
        \\  }
        \\}
    ;

    var result = try createResponseWithTransport(std.testing.allocator, .{ .api_key = "test-key" }, http.FakeTransport{ .body = body }, .{
        .slug = "openai-preset",
        .request = .{
            .model = "openai/o4-mini",
            .input = .{ .text = "Hello" },
        },
    }, .{});
    defer result.deinit();

    try std.testing.expectEqualStrings("preset_resp_123", result.data.id);
    try std.testing.expectEqualStrings("openai-preset", result.data.slug);
    try std.testing.expectEqualStrings("version_resp_123", result.data.designated_version.?.id);
}

test "preset responses create sends POST /presets/{slug}/responses" {
    const path = try responsesPath(std.testing.allocator, "openai preset");
    defer std.testing.allocator.free(path);

    var prepared = try http.prepareRequest(std.testing.allocator, .{ .api_key = "test-key" }, .{
        .method = .POST,
        .path = path,
        .body = "{}",
    }, .{});
    defer prepared.deinit();

    try std.testing.expectEqual(std.http.Method.POST, prepared.method);
    try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/presets/openai%20preset/responses", prepared.url);
}

test "preset responses create maps error status to ApiError" {
    try std.testing.expectError(error.ApiError, createResponseWithTransport(
        std.testing.allocator,
        .{ .api_key = "test-key" },
        http.FakeTransport{ .status = .bad_request, .body = "{\"error\":{\"message\":\"bad preset\"}}" },
        .{
            .slug = "openai-preset",
            .request = .{
                .model = "openai/o4-mini",
                .input = .{ .text = "Hello" },
            },
        },
        .{},
    ));
}
