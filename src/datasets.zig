//! Datasets API.

const std = @import("std");

const config_mod = @import("config.zig");
const errors = @import("errors.zig");
const http = @import("http.zig");
const json = @import("json.zig");
const options_mod = @import("options.zig");
const query_mod = @import("query.zig");

pub const RankingsDailyGetRequest = struct {
    start_date: ?[]const u8 = null,
    end_date: ?[]const u8 = null,
};

pub const RankingsDailyGetResponse = struct {
    arena: std.heap.ArenaAllocator,
    data: []RankingDailyItem,
    meta: RankingDailyMeta,

    pub fn deinit(self: *RankingsDailyGetResponse) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

pub const RankingDailyItem = struct {
    date: []const u8,
    model_permaslug: []const u8,
    total_tokens: []const u8,
};

pub const RankingDailyMeta = struct {
    as_of: []const u8,
    end_date: []const u8,
    start_date: []const u8,
    version: []const u8,
};

const WireRankingsDailyGetResponse = struct {
    data: []RankingDailyItem,
    meta: RankingDailyMeta,
};

pub fn getRankingsDaily(client: anytype, request: RankingsDailyGetRequest, request_options: options_mod.RequestOptions) !RankingsDailyGetResponse {
    return getRankingsDailyWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, request, request_options);
}

pub fn getRankingsDailyWithTransport(
    allocator: std.mem.Allocator,
    config: config_mod.Config,
    transport: anytype,
    request: RankingsDailyGetRequest,
    request_options: options_mod.RequestOptions,
) !RankingsDailyGetResponse {
    const query = try rankingsDailyQueryString(allocator, request);
    defer allocator.free(query);

    var prepared = try http.prepareRequest(allocator, config, .{
        .method = .GET,
        .path = "/datasets/rankings-daily",
        .query = query,
    }, request_options);
    defer prepared.deinit();

    var response = try transport.execute(allocator, prepared);
    defer response.deinit();

    return parseRankingsDailyGetResponse(allocator, response);
}

pub fn parseRankingsDailyGetResponse(allocator: std.mem.Allocator, response: http.HttpResponse) !RankingsDailyGetResponse {
    if (errors.isErrorStatus(@intFromEnum(response.status))) return error.ApiError;

    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const arena_allocator = arena.allocator();

    const owned_body = try arena_allocator.dupe(u8, response.body);
    const parsed = try json.parseResponseLeaky(WireRankingsDailyGetResponse, arena_allocator, owned_body);
    return .{
        .arena = arena,
        .data = parsed.data,
        .meta = parsed.meta,
    };
}

pub fn rankingsDailyQueryString(allocator: std.mem.Allocator, request: RankingsDailyGetRequest) ![]u8 {
    return query_mod.build(allocator, &.{
        .{ .name = "start_date", .value = request.start_date },
        .{ .name = "end_date", .value = request.end_date },
    });
}

test "rankings daily get parses response and ignores unknown fields" {
    const body =
        \\{
        \\  "data": [
        \\    {
        \\      "date": "2026-05-11",
        \\      "model_permaslug": "openai/gpt-4o-2024-05-13",
        \\      "total_tokens": "12345678",
        \\      "unknown": true
        \\    }
        \\  ],
        \\  "meta": {
        \\    "as_of": "2026-05-12T02:00:00Z",
        \\    "end_date": "2026-05-11",
        \\    "start_date": "2026-04-12",
        \\    "version": "v1",
        \\    "unknown": true
        \\  },
        \\  "unknown": true
        \\}
    ;

    var result = try getRankingsDailyWithTransport(std.testing.allocator, config_mod.Config{ .api_key = "test-key" }, http.FakeTransport{ .body = body }, .{}, .{});
    defer result.deinit();

    try std.testing.expectEqual(@as(usize, 1), result.data.len);
    try std.testing.expectEqualStrings("2026-05-11", result.data[0].date);
    try std.testing.expectEqualStrings("openai/gpt-4o-2024-05-13", result.data[0].model_permaslug);
    try std.testing.expectEqualStrings("12345678", result.data[0].total_tokens);
    try std.testing.expectEqualStrings("2026-05-12T02:00:00Z", result.meta.as_of);
    try std.testing.expectEqualStrings("2026-05-11", result.meta.end_date);
    try std.testing.expectEqualStrings("2026-04-12", result.meta.start_date);
    try std.testing.expectEqualStrings("v1", result.meta.version);
}

test "rankings daily get sends GET /datasets/rankings-daily without query" {
    const query = try rankingsDailyQueryString(std.testing.allocator, .{});
    defer std.testing.allocator.free(query);

    var prepared = try http.prepareRequest(std.testing.allocator, .{ .api_key = "test-key" }, .{
        .method = .GET,
        .path = "/datasets/rankings-daily",
        .query = query,
    }, .{});
    defer prepared.deinit();

    try std.testing.expectEqual(std.http.Method.GET, prepared.method);
    try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/datasets/rankings-daily", prepared.url);
}

test "rankings daily get sends escaped optional query params" {
    const query = try rankingsDailyQueryString(std.testing.allocator, .{
        .start_date = "2026-04-12",
        .end_date = "2026-05-11",
    });
    defer std.testing.allocator.free(query);

    var prepared = try http.prepareRequest(std.testing.allocator, .{ .api_key = "test-key" }, .{
        .method = .GET,
        .path = "/datasets/rankings-daily",
        .query = query,
    }, .{});
    defer prepared.deinit();

    try std.testing.expectEqual(std.http.Method.GET, prepared.method);
    try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/datasets/rankings-daily?start_date=2026-04-12&end_date=2026-05-11", prepared.url);
}

test "rankings daily get maps error status to ApiError" {
    try std.testing.expectError(error.ApiError, getRankingsDailyWithTransport(
        std.testing.allocator,
        config_mod.Config{ .api_key = "test-key" },
        http.FakeTransport{ .status = .bad_request, .body = "{\"error\":{\"message\":\"invalid date\"}}" },
        .{},
        .{},
    ));
}
