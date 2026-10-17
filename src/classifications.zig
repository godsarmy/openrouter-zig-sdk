//! Task classifications API.

const std = @import("std");

const config_mod = @import("config.zig");
const errors = @import("errors.zig");
const http = @import("http.zig");
const json = @import("json.zig");
const options_mod = @import("options.zig");
const query_mod = @import("query.zig");

pub const TaskWindow = enum { @"7d" };

pub const TaskGetRequest = struct {
    window: ?TaskWindow = null,
};

/// All fields, including `response_metadata`, are owned by this response and
/// remain valid until `deinit`.
pub const TaskGetResponse = struct {
    arena: std.heap.ArenaAllocator,
    data: TaskData,
    response_metadata: http.ResponseMetadata = .{},

    pub fn deinit(self: *TaskGetResponse) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

pub const TaskData = struct {
    window_days: u64,
    as_of: []const u8,
    classifications: []Classification,
    macro_categories: []MacroCategory,
};

pub const Classification = struct {
    tag: []const u8,
    display_name: []const u8,
    macro_category: []const u8,
    usage_share: f64,
    token_share: f64,
    category_usage_share: f64,
    category_token_share: f64,
    models: []ClassificationModel,
};

pub const ClassificationModel = struct {
    id: []const u8,
    tag_usage_share: f64,
    tag_token_share: f64,
};

pub const MacroCategory = struct {
    key: []const u8,
    label: []const u8,
    usage_share: f64,
    token_share: f64,
};

const Wire = struct {
    data: TaskData,
};

pub fn get(
    client: anytype,
    request: TaskGetRequest,
    request_options: options_mod.RequestOptions,
) !TaskGetResponse {
    return getWithTransport(
        client.allocator,
        client.config,
        http.RealTransport{ .client = &client.http_client },
        request,
        request_options,
    );
}

pub fn getWithTransport(
    allocator: std.mem.Allocator,
    config: config_mod.Config,
    transport: anytype,
    request: TaskGetRequest,
    request_options: options_mod.RequestOptions,
) !TaskGetResponse {
    const query = try queryString(allocator, request);
    defer allocator.free(query);

    var prepared = try http.prepareRequest(allocator, config, .{
        .method = .GET,
        .path = "/classifications/task",
        .query = query,
    }, request_options);
    defer prepared.deinit();

    var response = try transport.execute(allocator, prepared);
    defer response.deinit();

    return parseGetResponse(allocator, response);
}

pub fn parseGetResponse(
    allocator: std.mem.Allocator,
    response: http.HttpResponse,
) !TaskGetResponse {
    if (errors.isErrorStatus(@backingInt(response.status))) return error.ApiError;

    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const arena_allocator = arena.allocator();

    const body = try arena_allocator.dupe(u8, response.body);
    const parsed = try json.parseResponseLeaky(Wire, arena_allocator, body);

    return .{
        .arena = arena,
        .data = parsed.data,
        .response_metadata = try http.ResponseMetadata.fromHttpResponse(arena_allocator, response),
    };
}

pub fn queryString(allocator: std.mem.Allocator, request: TaskGetRequest) ![]u8 {
    return query_mod.build(allocator, &.{
        .{
            .name = "window",
            .value = if (request.window) |value| @tagName(value) else null,
        },
    });
}

test "classifications task parses nested and empty data" {
    const body =
        \\{
        \\  "data": {
        \\    "window_days": 7,
        \\    "as_of": "2026-10-17",
        \\    "classifications": [
        \\      {
        \\        "tag": "coding",
        \\        "display_name": "Coding",
        \\        "macro_category": "work",
        \\        "usage_share": 0.2,
        \\        "token_share": 0.3,
        \\        "category_usage_share": 0.4,
        \\        "category_token_share": 0.5,
        \\        "models": [
        \\          {
        \\            "id": "openai/gpt",
        \\            "tag_usage_share": 0.6,
        \\            "tag_token_share": 0.7
        \\          }
        \\        ]
        \\      }
        \\    ],
        \\    "macro_categories": []
        \\  },
        \\  "unknown": true
        \\}
    ;

    var result = try getWithTransport(
        std.testing.allocator,
        .{ .api_key = "test" },
        http.FakeTransport{ .body = body },
        .{},
        .{},
    );
    defer result.deinit();

    try std.testing.expectEqual(@as(usize, 1), result.data.classifications.len);
    try std.testing.expectEqualStrings("openai/gpt", result.data.classifications[0].models[0].id);
    try std.testing.expectEqual(@as(usize, 0), result.data.macro_categories.len);
}

test "classifications task sends optional window and omits defaults" {
    const absent = try queryString(std.testing.allocator, .{});
    defer std.testing.allocator.free(absent);
    try std.testing.expectEqualStrings("", absent);

    const query = try queryString(std.testing.allocator, .{ .window = .@"7d" });
    defer std.testing.allocator.free(query);

    var prepared = try http.prepareRequest(std.testing.allocator, .{ .api_key = "test" }, .{
        .method = .GET,
        .path = "/classifications/task",
        .query = query,
    }, .{});
    defer prepared.deinit();

    try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/classifications/task?window=7d", prepared.url);
}

test "classifications task maps errors and rejects missing required fields" {
    try std.testing.expectError(error.ApiError, getWithTransport(
        std.testing.allocator,
        .{ .api_key = "test" },
        http.FakeTransport{ .status = .bad_request },
        .{},
        .{},
    ));

    const missing_fields_body =
        \\{ "data": {} }
    ;
    try std.testing.expectError(error.MissingField, getWithTransport(
        std.testing.allocator,
        .{ .api_key = "test" },
        http.FakeTransport{ .body = missing_fields_body },
        .{},
        .{},
    ));
}
