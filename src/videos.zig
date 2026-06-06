//! Video generation API.

const std = @import("std");

const config_mod = @import("config.zig");
const errors = @import("errors.zig");
const http = @import("http.zig");
const json = @import("json.zig");
const options_mod = @import("options.zig");
const query_mod = @import("query.zig");

pub const CreateRequest = struct {
    model: []const u8,
    prompt: []const u8,
    aspect_ratio: ?[]const u8 = null,
    duration: ?u32 = null,
    resolution: ?[]const u8 = null,
    size: ?[]const u8 = null,
    frame_images: ?[]const FrameImage = null,
    input_references: ?[]const InputReference = null,
    generate_audio: ?bool = null,
    seed: ?i64 = null,
    callback_url: ?[]const u8 = null,
    provider: ?std.json.Value = null,
};

pub const FrameImage = struct {
    type: []const u8 = "image_url",
    image_url: UrlReference,
    frame_type: []const u8,
};

pub const UrlReference = struct {
    url: []const u8,
};

pub const InputReference = union(enum) {
    image_url: UrlReference,
    input_audio: UrlReference,
    input_video: UrlReference,

    pub fn jsonStringify(self: InputReference, jws: anytype) !void {
        try jws.beginObject();
        switch (self) {
            .image_url => |value| {
                try jws.objectField("type");
                try jws.write("image_url");
                try jws.objectField("image_url");
                try jws.write(value);
            },
            .input_audio => |value| {
                try jws.objectField("type");
                try jws.write("input_audio");
                try jws.objectField("input_audio");
                try jws.write(value);
            },
            .input_video => |value| {
                try jws.objectField("type");
                try jws.write("input_video");
                try jws.objectField("input_video");
                try jws.write(value);
            },
        }
        try jws.endObject();
    }
};

pub const GetRequest = struct {
    job_id: []const u8,
};

pub const ContentRequest = struct {
    job_id: []const u8,
    index: ?u32 = null,
};

pub const JobResponse = struct {
    arena: std.heap.ArenaAllocator,
    id: []const u8,
    polling_url: []const u8,
    status: Status,
    err: ?[]const u8 = null,
    generation_id: ?[]const u8 = null,
    unsigned_urls: ?[]const []const u8 = null,
    usage: ?Usage = null,

    pub fn deinit(self: *JobResponse) void {
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
};

pub const ModelsListResponse = struct {
    arena: std.heap.ArenaAllocator,
    data: []VideoModel,

    pub fn deinit(self: *ModelsListResponse) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

pub const Status = enum {
    pending,
    in_progress,
    completed,
    failed,
    cancelled,
    expired,
};

pub const Usage = struct {
    cost: ?f64 = null,
    is_byok: ?bool = null,
};

pub const VideoModel = struct {
    id: []const u8,
    canonical_slug: ?[]const u8 = null,
    created: ?i64 = null,
    name: []const u8,
    description: ?[]const u8 = null,
    allowed_passthrough_parameters: ?[]const []const u8 = null,
    generate_audio: ?bool = null,
    hugging_face_id: ?[]const u8 = null,
    pricing_skus: ?std.json.Value = null,
    seed: ?bool = null,
    supported_aspect_ratios: ?[]const []const u8 = null,
    supported_durations: ?[]const u32 = null,
    supported_frame_images: ?[]const []const u8 = null,
    supported_resolutions: ?[]const []const u8 = null,
    supported_sizes: ?[]const []const u8 = null,
};

const WireJobResponse = struct {
    id: []const u8,
    polling_url: []const u8,
    status: Status,
    @"error": ?[]const u8 = null,
    generation_id: ?[]const u8 = null,
    unsigned_urls: ?[]const []const u8 = null,
    usage: ?Usage = null,
};

const WireModelsListResponse = struct {
    data: []VideoModel,
};

pub fn create(client: anytype, request: CreateRequest, request_options: options_mod.RequestOptions) !JobResponse {
    return createWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, request, request_options);
}

pub fn createWithTransport(
    allocator: std.mem.Allocator,
    config: config_mod.Config,
    transport: anytype,
    request: CreateRequest,
    request_options: options_mod.RequestOptions,
) !JobResponse {
    const body = try json.stringifyRequest(allocator, request);
    defer allocator.free(body);

    var prepared = try http.prepareRequest(allocator, config, .{
        .method = .POST,
        .path = "/videos",
        .body = body,
    }, request_options);
    defer prepared.deinit();

    var response = try transport.execute(allocator, prepared);
    defer response.deinit();

    return parseJobResponse(allocator, response);
}

pub fn get(client: anytype, request: GetRequest, request_options: options_mod.RequestOptions) !JobResponse {
    return getWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, request, request_options);
}

pub fn getWithTransport(
    allocator: std.mem.Allocator,
    config: config_mod.Config,
    transport: anytype,
    request: GetRequest,
    request_options: options_mod.RequestOptions,
) !JobResponse {
    const path = try jobPath(allocator, request.job_id, null);
    defer allocator.free(path);

    var prepared = try http.prepareRequest(allocator, config, .{
        .method = .GET,
        .path = path,
    }, request_options);
    defer prepared.deinit();

    var response = try transport.execute(allocator, prepared);
    defer response.deinit();

    return parseJobResponse(allocator, response);
}

pub fn content(client: anytype, request: ContentRequest, request_options: options_mod.RequestOptions) !ContentResponse {
    return contentWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, request, request_options);
}

pub fn contentWithTransport(
    allocator: std.mem.Allocator,
    config: config_mod.Config,
    transport: anytype,
    request: ContentRequest,
    request_options: options_mod.RequestOptions,
) !ContentResponse {
    const path = try jobPath(allocator, request.job_id, "/content");
    defer allocator.free(path);
    const query = try contentQueryString(allocator, request);
    defer allocator.free(query);

    var prepared = try http.prepareRequest(allocator, config, .{
        .method = .GET,
        .path = path,
        .query = query,
        .accept = "application/octet-stream",
        .content_type = null,
    }, request_options);
    defer prepared.deinit();

    var response = try transport.execute(allocator, prepared);
    if (errors.isErrorStatus(@intFromEnum(response.status))) {
        response.deinit();
        return error.ApiError;
    }

    return .{ .response = response };
}

pub fn listModels(client: anytype, request_options: options_mod.RequestOptions) !ModelsListResponse {
    return listModelsWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, request_options);
}

pub fn listModelsWithTransport(
    allocator: std.mem.Allocator,
    config: config_mod.Config,
    transport: anytype,
    request_options: options_mod.RequestOptions,
) !ModelsListResponse {
    var prepared = try http.prepareRequest(allocator, config, .{
        .method = .GET,
        .path = "/videos/models",
    }, request_options);
    defer prepared.deinit();

    var response = try transport.execute(allocator, prepared);
    defer response.deinit();

    return parseModelsListResponse(allocator, response);
}

pub fn parseJobResponse(allocator: std.mem.Allocator, response: http.HttpResponse) !JobResponse {
    if (errors.isErrorStatus(@intFromEnum(response.status))) return error.ApiError;

    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const arena_allocator = arena.allocator();

    const owned_body = try arena_allocator.dupe(u8, response.body);
    const parsed = try json.parseResponseLeaky(WireJobResponse, arena_allocator, owned_body);
    return .{
        .arena = arena,
        .id = parsed.id,
        .polling_url = parsed.polling_url,
        .status = parsed.status,
        .err = parsed.@"error",
        .generation_id = parsed.generation_id,
        .unsigned_urls = parsed.unsigned_urls,
        .usage = parsed.usage,
    };
}

pub fn parseModelsListResponse(allocator: std.mem.Allocator, response: http.HttpResponse) !ModelsListResponse {
    if (errors.isErrorStatus(@intFromEnum(response.status))) return error.ApiError;

    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const arena_allocator = arena.allocator();

    const owned_body = try arena_allocator.dupe(u8, response.body);
    const parsed = try json.parseResponseLeaky(WireModelsListResponse, arena_allocator, owned_body);
    return .{
        .arena = arena,
        .data = parsed.data,
    };
}

fn contentQueryString(allocator: std.mem.Allocator, request: ContentRequest) ![]u8 {
    var index_buffer: [16]u8 = undefined;
    const index = if (request.index) |value| try std.fmt.bufPrint(&index_buffer, "{d}", .{value}) else null;
    return query_mod.build(allocator, &.{.{ .name = "index", .value = index }});
}

fn jobPath(allocator: std.mem.Allocator, job_id: []const u8, suffix: ?[]const u8) ![]u8 {
    var path: std.ArrayList(u8) = .empty;
    errdefer path.deinit(allocator);

    try path.appendSlice(allocator, "/videos/");
    try appendPathSegment(allocator, &path, job_id);
    if (suffix) |value| try path.appendSlice(allocator, value);

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

test "videos create serializes request" {
    const body = try json.stringifyRequest(std.testing.allocator, CreateRequest{
        .model = "google/veo-3.1",
        .prompt = "A serene mountain landscape at sunset",
        .aspect_ratio = "16:9",
        .duration = 8,
        .resolution = "720p",
    });
    defer std.testing.allocator.free(body);

    try std.testing.expect(std.mem.indexOf(u8, body, "\"model\":\"google/veo-3.1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"prompt\":\"A serene mountain landscape at sunset\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"aspect_ratio\":\"16:9\"") != null);
}

test "videos create parses accepted job response" {
    const body =
        \\{
        \\  "id": "job-abc123",
        \\  "polling_url": "https://openrouter.ai/api/v1/videos/job-abc123",
        \\  "status": "pending",
        \\  "unknown": true
        \\}
    ;

    var result = try createWithTransport(std.testing.allocator, .{ .api_key = "test-key" }, http.FakeTransport{ .status = .accepted, .body = body }, .{
        .model = "google/veo-3.1",
        .prompt = "A serene mountain landscape at sunset",
    }, .{});
    defer result.deinit();

    try std.testing.expectEqualStrings("job-abc123", result.id);
    try std.testing.expectEqual(Status.pending, result.status);
}

test "videos get parses completed job response" {
    const body =
        \\{
        \\  "id": "job-abc123",
        \\  "polling_url": "https://openrouter.ai/api/v1/videos/job-abc123",
        \\  "status": "completed",
        \\  "generation_id": "gen-xyz789",
        \\  "unsigned_urls": ["https://example.com/video.mp4"],
        \\  "usage": { "cost": 0.5, "is_byok": false }
        \\}
    ;

    var result = try getWithTransport(std.testing.allocator, .{ .api_key = "test-key" }, http.FakeTransport{ .body = body }, .{ .job_id = "job-abc123" }, .{});
    defer result.deinit();

    try std.testing.expectEqual(Status.completed, result.status);
    try std.testing.expectEqualStrings("gen-xyz789", result.generation_id.?);
    try std.testing.expectEqual(@as(?f64, 0.5), result.usage.?.cost);
}

test "videos content returns binary body" {
    var result = try contentWithTransport(std.testing.allocator, .{ .api_key = "test-key" }, http.FakeTransport{ .body = "mp4-bytes" }, .{
        .job_id = "job-abc123",
        .index = 1,
    }, .{});
    defer result.deinit();

    try std.testing.expectEqualStrings("mp4-bytes", result.data());
}

test "videos models list parses response" {
    const body =
        \\{
        \\  "data": [
        \\    {
        \\      "id": "google/veo-3.1",
        \\      "canonical_slug": "google/veo-3.1",
        \\      "created": 1719792000,
        \\      "name": "Google: Veo 3.1",
        \\      "description": "Video generation model",
        \\      "allowed_passthrough_parameters": ["output_config"],
        \\      "generate_audio": true,
        \\      "seed": false,
        \\      "supported_aspect_ratios": ["16:9", "9:16"],
        \\      "supported_durations": [5, 8]
        \\    }
        \\  ]
        \\}
    ;

    var result = try listModelsWithTransport(std.testing.allocator, .{ .api_key = "test-key" }, http.FakeTransport{ .body = body }, .{});
    defer result.deinit();

    try std.testing.expectEqual(@as(usize, 1), result.data.len);
    try std.testing.expectEqualStrings("google/veo-3.1", result.data[0].id);
    try std.testing.expectEqualStrings("Google: Veo 3.1", result.data[0].name);
    try std.testing.expectEqual(@as(?bool, true), result.data[0].generate_audio);
    try std.testing.expectEqual(@as(u32, 8), result.data[0].supported_durations.?[1]);
}

test "videos paths and content query are escaped" {
    const path = try jobPath(std.testing.allocator, "job/id 1", "/content");
    defer std.testing.allocator.free(path);
    try std.testing.expectEqualStrings("/videos/job%2Fid%201/content", path);

    const query = try contentQueryString(std.testing.allocator, .{ .job_id = "job", .index = 2 });
    defer std.testing.allocator.free(query);
    try std.testing.expectEqualStrings("index=2", query);
}

test "videos create maps error status to ApiError" {
    try std.testing.expectError(error.ApiError, createWithTransport(
        std.testing.allocator,
        .{ .api_key = "test-key" },
        http.FakeTransport{ .status = .bad_request, .body = "{\"error\":{\"message\":\"bad request\"}}" },
        .{ .model = "google/veo-3.1", .prompt = "prompt" },
        .{},
    ));
}
