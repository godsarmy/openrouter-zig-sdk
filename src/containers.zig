//! Container files. Promotion copies into durable Files storage and consumes workspace quota.
const std = @import("std");
const common = @import("enterprise.zig");
const config_mod = @import("config.zig");
const http = @import("http.zig");
const json = @import("json.zig");
const options_mod = @import("options.zig");
const query = @import("query.zig");
pub const File = struct { id: []const u8, object: []const u8, container_id: []const u8, bytes: u64, created_at: i64, path: []const u8, source: []const u8 };
pub const FileList = struct {
    object: []const u8,
    data: []File,
    first_id: ?[]const u8,
    /// Resume cursor even when data is empty at a scan boundary.
    last_id: ?[]const u8,
    has_more: bool,
};
pub const ListRequest = struct { limit: ?u64 = null, after: ?[]const u8 = null };
fn listQuery(allocator: std.mem.Allocator, request: ListRequest) ![]u8 {
    var limit: [20]u8 = undefined;
    return query.build(allocator, &.{
        .{ .name = "limit", .value = if (request.limit) |v| try std.fmt.bufPrint(&limit, "{d}", .{v}) else null },
        .{ .name = "after", .value = request.after },
    });
}

pub const ListFilesResponse = common.Response(FileList);
pub fn listFiles(client: anytype, container_id: []const u8, request: ListRequest, request_options: options_mod.RequestOptions) !ListFilesResponse {
    return listFilesWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, container_id, request, request_options);
}
pub fn listFilesWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, container_id: []const u8, request: ListRequest, request_options: options_mod.RequestOptions) !ListFilesResponse {
    const encoded_container_id = try common.segment(allocator, container_id);
    defer allocator.free(encoded_container_id);
    const path = try std.fmt.allocPrint(allocator, "/containers/{s}/files", .{encoded_container_id});
    defer allocator.free(path);
    const query_string = try listQuery(allocator, request);
    defer allocator.free(query_string);
    return common.execute(ListFilesResponse.Payload, allocator, config, transport, .{ .method = .GET, .path = path, .query = query_string }, request_options);
}
pub const GetFileResponse = common.Response(File);
pub fn getFile(client: anytype, container_id: []const u8, file_id: []const u8, request_options: options_mod.RequestOptions) !GetFileResponse {
    return getFileWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, container_id, file_id, request_options);
}
pub fn getFileWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, container_id: []const u8, file_id: []const u8, request_options: options_mod.RequestOptions) !GetFileResponse {
    const encoded_container_id = try common.segment(allocator, container_id);
    defer allocator.free(encoded_container_id);
    const encoded_file_id = try common.segment(allocator, file_id);
    defer allocator.free(encoded_file_id);
    const path = try std.fmt.allocPrint(allocator, "/containers/{s}/files/{s}", .{ encoded_container_id, encoded_file_id });
    defer allocator.free(path);
    return common.execute(GetFileResponse.Payload, allocator, config, transport, .{ .method = .GET, .path = path }, request_options);
}
pub const PromoteFileResponse = common.Response(@import("files.zig").FileMetadata);
pub fn promoteFile(client: anytype, container_id: []const u8, file_id: []const u8, request_options: options_mod.RequestOptions) !PromoteFileResponse {
    return promoteFileWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, container_id, file_id, request_options);
}
pub fn promoteFileWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, container_id: []const u8, file_id: []const u8, request_options: options_mod.RequestOptions) !PromoteFileResponse {
    const encoded_container_id = try common.segment(allocator, container_id);
    defer allocator.free(encoded_container_id);
    const encoded_file_id = try common.segment(allocator, file_id);
    defer allocator.free(encoded_file_id);
    const path = try std.fmt.allocPrint(allocator, "/containers/{s}/files/{s}/promote", .{ encoded_container_id, encoded_file_id });
    defer allocator.free(path);
    return common.execute(PromoteFileResponse.Payload, allocator, config, transport, .{ .method = .POST, .path = path }, request_options);
}

/// Buffered binary content. Owns the HTTP response until deinit.
pub const ContentResponse = @import("files.zig").ContentResponse;
pub fn content(client: anytype, container_id: []const u8, file_id: []const u8, request_options: options_mod.RequestOptions) !ContentResponse {
    return contentWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, container_id, file_id, request_options);
}
pub fn contentWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, container_id: []const u8, file_id: []const u8, request_options: options_mod.RequestOptions) !ContentResponse {
    const container = try common.segment(allocator, container_id);
    defer allocator.free(container);
    const file = try common.segment(allocator, file_id);
    defer allocator.free(file);
    const path = try std.fmt.allocPrint(allocator, "/containers/{s}/files/{s}/content", .{ container, file });
    defer allocator.free(path);
    var prepared = try http.prepareRequest(allocator, config, .{ .method = .GET, .path = path, .accept = "application/octet-stream" }, request_options);
    defer prepared.deinit();
    var response = try transport.execute(allocator, prepared);
    errdefer response.deinit();
    if (@backingInt(response.status) >= 400) return error.ApiError;
    return .{ .response = response };
}

test "listFiles uses scoped escaped path and parses 200" {
    const Transport = struct {
        pub fn execute(_: @This(), allocator: std.mem.Allocator, prepared: http.PreparedRequest) !http.HttpResponse {
            try std.testing.expectEqual(std.http.Method.GET, prepared.method);
            try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/containers/a%2Fb/files?limit=2&after=scan%2F%3F", prepared.url);
            try std.testing.expect(prepared.body == null);
            return (http.FakeTransport{ .status = @fromBackingInt(200), .body = "{\"data\":[{\"bytes\":123,\"container_id\":\"sess_abc123\",\"created_at\":1755640000,\"id\":\"cfile_b3V0L3JlcG9ydC5jc3Y\",\"object\":\"container.file\",\"path\":\"out/report.csv\",\"source\":\"assistant\"}],\"first_id\":\"cfile_b3V0L3JlcG9ydC5jc3Y\",\"has_more\":false,\"last_id\":\"cfile_b3V0L3JlcG9ydC5jc3Y\",\"object\":\"list\"}", .headers = &.{.{ .name = "x-request-id", .value = "owned" }} }).execute(allocator, prepared);
        }
    };
    var result = try listFilesWithTransport(std.testing.allocator, .{ .api_key = "test" }, Transport{}, "a/b", .{ .limit = 2, .after = "scan/?" }, .{});
    defer result.deinit();
    try std.testing.expectEqualStrings("owned", result.response_metadata.request_id.?);
    try std.testing.expectError(error.ApiError, listFilesWithTransport(std.testing.allocator, .{ .api_key = "test" }, http.FakeTransport{ .status = .forbidden }, "a/b", .{ .limit = 2, .after = "scan/?" }, .{}));
}
test "getFile uses scoped escaped path and parses 200" {
    const Transport = struct {
        pub fn execute(_: @This(), allocator: std.mem.Allocator, prepared: http.PreparedRequest) !http.HttpResponse {
            try std.testing.expectEqual(std.http.Method.GET, prepared.method);
            try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/containers/a%2Fb/files/c%3Fd", prepared.url);
            try std.testing.expect(prepared.body == null);
            return (http.FakeTransport{ .status = @fromBackingInt(200), .body = "{\"bytes\":123,\"container_id\":\"sess_abc123\",\"created_at\":1755640000,\"id\":\"cfile_b3V0L3JlcG9ydC5jc3Y\",\"object\":\"container.file\",\"path\":\"out/report.csv\",\"source\":\"assistant\"}", .headers = &.{.{ .name = "x-request-id", .value = "owned" }} }).execute(allocator, prepared);
        }
    };
    var result = try getFileWithTransport(std.testing.allocator, .{ .api_key = "test" }, Transport{}, "a/b", "c?d", .{});
    defer result.deinit();
    try std.testing.expectEqualStrings("owned", result.response_metadata.request_id.?);
    try std.testing.expectError(error.ApiError, getFileWithTransport(std.testing.allocator, .{ .api_key = "test" }, http.FakeTransport{ .status = .forbidden }, "a/b", "c?d", .{}));
}
test "promoteFile uses scoped escaped path and parses 200" {
    const Transport = struct {
        pub fn execute(_: @This(), allocator: std.mem.Allocator, prepared: http.PreparedRequest) !http.HttpResponse {
            try std.testing.expectEqual(std.http.Method.POST, prepared.method);
            try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/containers/a%2Fb/files/c%3Fd/promote", prepared.url);
            try std.testing.expect(prepared.body == null);
            return (http.FakeTransport{ .status = @fromBackingInt(200), .body = "{\"_shape\":\"openrouter\",\"created_at\":\"2026-08-23T00:00:00Z\",\"downloadable\":true,\"filename\":\"out/report.csv\",\"id\":\"or_file_011CNha8iCJcU1wXNR6q4V8w\",\"mime_type\":\"text/csv\",\"size_bytes\":123,\"type\":\"file\"}", .headers = &.{.{ .name = "x-request-id", .value = "owned" }} }).execute(allocator, prepared);
        }
    };
    var result = try promoteFileWithTransport(std.testing.allocator, .{ .api_key = "test" }, Transport{}, "a/b", "c?d", .{});
    defer result.deinit();
    try std.testing.expectEqualStrings("owned", result.response_metadata.request_id.?);
    try std.testing.expectError(error.ApiError, promoteFileWithTransport(std.testing.allocator, .{ .api_key = "test" }, http.FakeTransport{ .status = .forbidden }, "a/b", "c?d", .{}));
}

test "container pagination retains scan cursor on empty page" {
    var result = try listFilesWithTransport(std.testing.allocator, .{ .api_key = "test" }, http.FakeTransport{ .body = "{\"object\":\"list\",\"data\":[],\"first_id\":null,\"last_id\":\"scan_boundary\",\"has_more\":true}" }, "container", .{}, .{});
    defer result.deinit();
    try std.testing.expect(result.value.has_more);
    try std.testing.expectEqual(@as(usize, 0), result.value.data.len);
    try std.testing.expectEqualStrings("scan_boundary", result.value.last_id.?);
}

test "container content preserves binary bytes and escapes both identifiers" {
    const Transport = struct {
        pub fn execute(_: @This(), allocator: std.mem.Allocator, prepared: http.PreparedRequest) !http.HttpResponse {
            try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/containers/a%2Fb/files/c%3Fd/content", prepared.url);
            for (prepared.headers) |h| {
                if (std.ascii.eqlIgnoreCase(h.name, "Accept")) try std.testing.expectEqualStrings("application/octet-stream", h.value);
            }
            return (http.FakeTransport{ .body = "\x00\xff\x01", .headers = &.{.{ .name = "Content-Type", .value = "application/octet-stream" }} }).execute(allocator, prepared);
        }
    };
    var result = try contentWithTransport(std.testing.allocator, .{ .api_key = "test" }, Transport{}, "a/b", "c?d", .{});
    defer result.deinit();
    try std.testing.expectEqualSlices(u8, "\x00\xff\x01", result.data());
    try std.testing.expectError(error.ApiError, contentWithTransport(std.testing.allocator, .{ .api_key = "test" }, http.FakeTransport{ .status = .not_found }, "a", "b", .{}));
    try std.testing.expectError(error.InvalidPath, getFileWithTransport(std.testing.allocator, .{ .api_key = "test" }, http.FakeTransport{}, "..", "b", .{}));
}
