//! Files API.

const std = @import("std");

const config_mod = @import("config.zig");
const errors = @import("errors.zig");
const http = @import("http.zig");
const json = @import("json.zig");
const options_mod = @import("options.zig");
const query_mod = @import("query.zig");

const multipart_boundary = "openrouter-zig-boundary";

pub const ListRequest = struct {
    limit: ?u64 = null,
    cursor: ?[]const u8 = null,
    workspace_id: ?[]const u8 = null,
};

pub const UploadRequest = struct {
    filename: []const u8,
    data: []const u8,
    mime_type: ?[]const u8 = null,
    workspace_id: ?[]const u8 = null,
};

pub const WorkspaceRequest = struct {
    workspace_id: ?[]const u8 = null,
};

pub const FileMetadata = struct {
    id: []const u8,
    type: []const u8,
    filename: []const u8,
    mime_type: []const u8,
    size_bytes: u64,
    created_at: []const u8,
    downloadable: bool,
};

pub const ListResponse = struct {
    arena: std.heap.ArenaAllocator,
    data: []FileMetadata,
    has_more: bool,
    first_id: ?[]const u8,
    last_id: ?[]const u8,
    cursor: ?[]const u8,

    pub fn deinit(self: *ListResponse) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

pub const MetadataResponse = struct {
    arena: std.heap.ArenaAllocator,
    data: FileMetadata,

    pub fn deinit(self: *MetadataResponse) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

pub const DeleteResponse = struct {
    arena: std.heap.ArenaAllocator,
    id: []const u8,
    type: []const u8,

    pub fn deinit(self: *DeleteResponse) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

pub const ContentResponse = struct {
    response: http.HttpResponse,

    pub fn deinit(self: *ContentResponse) void {
        self.response.deinit();
        self.* = undefined;
    }

    pub fn data(self: ContentResponse) []const u8 {
        return self.response.body;
    }

    pub fn contentType(self: ContentResponse) ?[]const u8 {
        return self.response.content_type;
    }
};

const WireListResponse = struct {
    data: []FileMetadata,
    has_more: bool,
    first_id: ?[]const u8,
    last_id: ?[]const u8,
    cursor: ?[]const u8,
};

const WireDeleteResponse = struct {
    id: []const u8,
    type: []const u8,
};

pub fn list(client: anytype, request: ListRequest, request_options: options_mod.RequestOptions) !ListResponse {
    return listWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, request, request_options);
}

pub fn upload(client: anytype, request: UploadRequest, request_options: options_mod.RequestOptions) !MetadataResponse {
    return uploadWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, request, request_options);
}

pub fn get(client: anytype, file_id: []const u8, request: WorkspaceRequest, request_options: options_mod.RequestOptions) !MetadataResponse {
    return getWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, file_id, request, request_options);
}

pub fn delete(client: anytype, file_id: []const u8, request: WorkspaceRequest, request_options: options_mod.RequestOptions) !DeleteResponse {
    return deleteWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, file_id, request, request_options);
}

pub fn content(client: anytype, file_id: []const u8, request: WorkspaceRequest, request_options: options_mod.RequestOptions) !ContentResponse {
    return contentWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, file_id, request, request_options);
}

pub fn listWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, request: ListRequest, request_options: options_mod.RequestOptions) !ListResponse {
    const query = try listQueryString(allocator, request);
    defer allocator.free(query);

    var response = try execute(allocator, config, transport, .{ .method = .GET, .path = "/files", .query = query }, request_options);
    defer response.deinit();
    return parseListResponse(allocator, response);
}

pub fn uploadWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, request: UploadRequest, request_options: options_mod.RequestOptions) !MetadataResponse {
    const query = try workspaceQueryString(allocator, .{ .workspace_id = request.workspace_id });
    defer allocator.free(query);
    const body = try multipartBody(allocator, request);
    defer allocator.free(body);

    var response = try execute(allocator, config, transport, .{
        .method = .POST,
        .path = "/files",
        .query = query,
        .body = body,
        .content_type = "multipart/form-data; boundary=" ++ multipart_boundary,
    }, request_options);
    defer response.deinit();
    return parseMetadataResponse(allocator, response);
}

pub fn getWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, file_id: []const u8, request: WorkspaceRequest, request_options: options_mod.RequestOptions) !MetadataResponse {
    const path = try filePath(allocator, file_id, "");
    defer allocator.free(path);
    const query = try workspaceQueryString(allocator, request);
    defer allocator.free(query);

    var response = try execute(allocator, config, transport, .{ .method = .GET, .path = path, .query = query }, request_options);
    defer response.deinit();
    return parseMetadataResponse(allocator, response);
}

pub fn deleteWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, file_id: []const u8, request: WorkspaceRequest, request_options: options_mod.RequestOptions) !DeleteResponse {
    const path = try filePath(allocator, file_id, "");
    defer allocator.free(path);
    const query = try workspaceQueryString(allocator, request);
    defer allocator.free(query);

    var response = try execute(allocator, config, transport, .{ .method = .DELETE, .path = path, .query = query }, request_options);
    defer response.deinit();
    return parseDeleteResponse(allocator, response);
}

pub fn contentWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, file_id: []const u8, request: WorkspaceRequest, request_options: options_mod.RequestOptions) !ContentResponse {
    const path = try filePath(allocator, file_id, "/content");
    defer allocator.free(path);
    const query = try workspaceQueryString(allocator, request);
    defer allocator.free(query);

    var response = try execute(allocator, config, transport, .{ .method = .GET, .path = path, .query = query, .accept = "application/octet-stream" }, request_options);
    if (errors.isErrorStatus(@intFromEnum(response.status))) {
        response.deinit();
        return error.ApiError;
    }
    return .{ .response = response };
}

fn execute(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, request: http.HttpRequest, request_options: options_mod.RequestOptions) !http.HttpResponse {
    var prepared = try http.prepareRequest(allocator, config, request, request_options);
    defer prepared.deinit();
    return try transport.execute(allocator, prepared);
}

pub fn parseListResponse(allocator: std.mem.Allocator, response: http.HttpResponse) !ListResponse {
    if (errors.isErrorStatus(@intFromEnum(response.status))) return error.ApiError;

    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const parsed = try json.parseResponseLeaky(WireListResponse, arena.allocator(), try arena.allocator().dupe(u8, response.body));
    return .{ .arena = arena, .data = parsed.data, .has_more = parsed.has_more, .first_id = parsed.first_id, .last_id = parsed.last_id, .cursor = parsed.cursor };
}

pub fn parseMetadataResponse(allocator: std.mem.Allocator, response: http.HttpResponse) !MetadataResponse {
    if (errors.isErrorStatus(@intFromEnum(response.status))) return error.ApiError;

    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const parsed = try json.parseResponseLeaky(FileMetadata, arena.allocator(), try arena.allocator().dupe(u8, response.body));
    return .{ .arena = arena, .data = parsed };
}

pub fn parseDeleteResponse(allocator: std.mem.Allocator, response: http.HttpResponse) !DeleteResponse {
    if (errors.isErrorStatus(@intFromEnum(response.status))) return error.ApiError;

    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const parsed = try json.parseResponseLeaky(WireDeleteResponse, arena.allocator(), try arena.allocator().dupe(u8, response.body));
    return .{ .arena = arena, .id = parsed.id, .type = parsed.type };
}

pub fn listQueryString(allocator: std.mem.Allocator, request: ListRequest) ![]u8 {
    const limit_str = if (request.limit) |value| try std.fmt.allocPrint(allocator, "{d}", .{value}) else null;
    defer if (limit_str) |value| allocator.free(value);

    return query_mod.build(allocator, &.{
        .{ .name = "limit", .value = limit_str },
        .{ .name = "cursor", .value = request.cursor },
        .{ .name = "workspace_id", .value = request.workspace_id },
    });
}

pub fn workspaceQueryString(allocator: std.mem.Allocator, request: WorkspaceRequest) ![]u8 {
    return query_mod.build(allocator, &.{.{ .name = "workspace_id", .value = request.workspace_id }});
}

pub fn multipartBody(allocator: std.mem.Allocator, request: UploadRequest) ![]u8 {
    var body: std.ArrayList(u8) = .empty;
    errdefer body.deinit(allocator);

    try body.writer(allocator).print(
        "--" ++ multipart_boundary ++ "\r\n" ++
            "Content-Disposition: form-data; name=\"file\"; filename=\"{s}\"\r\n" ++
            "Content-Type: {s}\r\n\r\n",
        .{ request.filename, request.mime_type orelse "application/octet-stream" },
    );
    try body.appendSlice(allocator, request.data);
    try body.appendSlice(allocator, "\r\n--" ++ multipart_boundary ++ "--\r\n");

    return try body.toOwnedSlice(allocator);
}

fn filePath(allocator: std.mem.Allocator, file_id: []const u8, suffix: []const u8) ![]u8 {
    return std.fmt.allocPrint(allocator, "/files/{s}{s}", .{ file_id, suffix });
}

test "files list serializes query params" {
    const query = try listQueryString(std.testing.allocator, .{ .limit = 100, .cursor = "cursor/with space", .workspace_id = "ws_123" });
    defer std.testing.allocator.free(query);
    try std.testing.expectEqualStrings("limit=100&cursor=cursor%2Fwith%20space&workspace_id=ws_123", query);
}

test "files list parses response" {
    var result = try listWithTransport(std.testing.allocator, .{ .api_key = "test-key" }, http.FakeTransport{ .body = "{\"data\":[{\"id\":\"file_123\",\"type\":\"file\",\"filename\":\"document.pdf\",\"mime_type\":\"application/pdf\",\"size_bytes\":1024,\"created_at\":\"2025-01-01T00:00:00Z\",\"downloadable\":false}],\"has_more\":false,\"first_id\":\"file_123\",\"last_id\":\"file_123\",\"cursor\":null}" }, .{}, .{});
    defer result.deinit();
    try std.testing.expectEqual(@as(usize, 1), result.data.len);
    try std.testing.expectEqualStrings("file_123", result.data[0].id);
    try std.testing.expect(!result.has_more);
    try std.testing.expect(result.cursor == null);
}

test "files upload builds multipart body and parses metadata" {
    const body = try multipartBody(std.testing.allocator, .{ .filename = "document.txt", .data = "hello", .mime_type = "text/plain" });
    defer std.testing.allocator.free(body);
    try std.testing.expect(std.mem.indexOf(u8, body, "name=\"file\"; filename=\"document.txt\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "Content-Type: text/plain") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "hello") != null);

    var result = try uploadWithTransport(std.testing.allocator, .{ .api_key = "test-key" }, http.FakeTransport{ .body = "{\"id\":\"file_123\",\"type\":\"file\",\"filename\":\"document.txt\",\"mime_type\":\"text/plain\",\"size_bytes\":5,\"created_at\":\"2025-01-01T00:00:00Z\",\"downloadable\":false}" }, .{ .filename = "document.txt", .data = "hello" }, .{});
    defer result.deinit();
    try std.testing.expectEqualStrings("document.txt", result.data.filename);
}

test "files get delete and content endpoints" {
    var got = try getWithTransport(std.testing.allocator, .{ .api_key = "test-key" }, http.FakeTransport{ .body = "{\"id\":\"file_123\",\"type\":\"file\",\"filename\":\"document.pdf\",\"mime_type\":\"application/pdf\",\"size_bytes\":1024,\"created_at\":\"2025-01-01T00:00:00Z\",\"downloadable\":true}" }, "file_123", .{}, .{});
    defer got.deinit();
    try std.testing.expectEqualStrings("application/pdf", got.data.mime_type);

    var deleted = try deleteWithTransport(std.testing.allocator, .{ .api_key = "test-key" }, http.FakeTransport{ .body = "{\"id\":\"file_123\",\"type\":\"file_deleted\"}" }, "file_123", .{}, .{});
    defer deleted.deinit();
    try std.testing.expectEqualStrings("file_deleted", deleted.type);

    var downloaded = try contentWithTransport(std.testing.allocator, .{ .api_key = "test-key" }, http.FakeTransport{ .body = "file bytes", .headers = &.{.{ .name = "content-type", .value = "application/octet-stream" }} }, "file_123", .{}, .{});
    defer downloaded.deinit();
    try std.testing.expectEqualStrings("file bytes", downloaded.data());
    try std.testing.expectEqualStrings("application/octet-stream", downloaded.contentType().?);
}

test "files paths and error mapping" {
    const path = try filePath(std.testing.allocator, "file_123", "/content");
    defer std.testing.allocator.free(path);
    try std.testing.expectEqualStrings("/files/file_123/content", path);
    try std.testing.expectError(error.ApiError, listWithTransport(std.testing.allocator, .{ .api_key = "test-key" }, http.FakeTransport{ .status = .unauthorized, .body = "{}" }, .{}, .{}));
    try std.testing.expectError(error.ApiError, contentWithTransport(std.testing.allocator, .{ .api_key = "test-key" }, http.FakeTransport{ .status = .bad_request, .body = "{}" }, "file_123", .{}, .{}));
}
