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

pub const AppRankingsGetRequest = struct {
    category: ?[]const u8 = null,
    subcategory: ?[]const u8 = null,
    sort: ?[]const u8 = null,
    start_date: ?[]const u8 = null,
    end_date: ?[]const u8 = null,
    limit: ?u64 = null,
    offset: ?u64 = null,
};

pub const BenchmarksArtificialAnalysisGetRequest = struct {
    max_results: ?u64 = null,
};

pub const BenchmarksDesignArenaGetRequest = struct {
    arena: ?[]const u8 = null,
    category: ?[]const u8 = null,
    max_results: ?u64 = null,
};

/// Filters weekly aggregate session-cost data. All fields are optional and
/// omitted from the request when unset.
pub const SessionCostRequest = struct {
    app_slug: ?[]const u8 = null,
    model: ?[]const u8 = null,
    turn_range: ?[]const u8 = null,
    limit: ?u64 = null,
    offset: ?u64 = null,
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

pub const AppRankingsGetResponse = struct {
    arena: std.heap.ArenaAllocator,
    data: []AppRankingsItem,
    meta: RankingDailyMeta,

    pub fn deinit(self: *AppRankingsGetResponse) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

pub const BenchmarksArtificialAnalysisGetResponse = struct {
    arena: std.heap.ArenaAllocator,
    data: []BenchmarkArtificialAnalysisItem,
    meta: BenchmarkArtificialAnalysisMeta,

    pub fn deinit(self: *BenchmarksArtificialAnalysisGetResponse) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

pub const BenchmarksDesignArenaGetResponse = struct {
    arena: std.heap.ArenaAllocator,
    data: []BenchmarkDesignArenaItem,
    meta: BenchmarkDesignArenaMeta,

    pub fn deinit(self: *BenchmarksDesignArenaGetResponse) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

/// Weekly aggregate session-cost data. All fields, including
/// `response_metadata`, are owned by this response until `deinit`.
pub const SessionCostResponse = struct {
    arena: std.heap.ArenaAllocator,
    data: []SessionCostItem,
    meta: SessionCostMeta,
    response_metadata: http.ResponseMetadata = .{},

    pub fn deinit(self: *SessionCostResponse) void {
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

pub const AppRankingsItem = struct {
    app_id: u64,
    app_name: []const u8,
    rank: u64,
    total_requests: u64,
    total_tokens: []const u8,
};

pub const BenchmarkPricing = struct {
    completion: []const u8,
    prompt: []const u8,
};

pub const BenchmarkArtificialAnalysisItem = struct {
    aa_name: []const u8,
    agentic_index: ?f64 = null,
    coding_index: ?f64 = null,
    intelligence_index: ?f64 = null,
    model_permaslug: []const u8,
    pricing: ?BenchmarkPricing = null,
};

pub const BenchmarkArtificialAnalysisMeta = struct {
    as_of: []const u8,
    citation: []const u8,
    model_count: u64,
    source: []const u8,
    source_url: []const u8,
    version: []const u8,
};

pub const TournamentStats = struct {
    first_place: ?u64 = null,
    fourth_place: ?u64 = null,
    second_place: ?u64 = null,
    third_place: ?u64 = null,
    total: ?u64 = null,
};

pub const BenchmarkDesignArenaItem = struct {
    arena: []const u8,
    avg_generation_time_ms: ?f64 = null,
    category: []const u8,
    display_name: []const u8,
    elo: f64,
    model_permaslug: []const u8,
    pricing: ?BenchmarkPricing = null,
    tournament_stats: TournamentStats,
    win_rate: f64,
};

pub const EloBounds = struct {
    max: f64,
    min: f64,
};

pub const BenchmarkDesignArenaMeta = struct {
    arena: []const u8,
    as_of: []const u8,
    category: ?[]const u8 = null,
    citation: []const u8,
    elo_bounds: EloBounds,
    model_count: u64,
    source: []const u8,
    source_url: []const u8,
    version: []const u8,
};

pub const SessionCostItem = struct {
    app_slug: []const u8,
    app_name: []const u8,
    turn_range: []const u8,
    model_permaslug: []const u8,
    median_session_cost_usd: f64,
};

pub const SessionCostMeta = struct {
    as_of: []const u8,
    version: []const u8,
    window_days: ?f64,
    window_end_date: ?[]const u8,
};

const WireRankingsDailyGetResponse = struct {
    data: []RankingDailyItem,
    meta: RankingDailyMeta,
};

const WireAppRankingsGetResponse = struct {
    data: []AppRankingsItem,
    meta: RankingDailyMeta,
};

const WireBenchmarksArtificialAnalysisGetResponse = struct {
    data: []BenchmarkArtificialAnalysisItem,
    meta: BenchmarkArtificialAnalysisMeta,
};

const WireBenchmarksDesignArenaGetResponse = struct {
    data: []BenchmarkDesignArenaItem,
    meta: BenchmarkDesignArenaMeta,
};

const WireSessionCostResponse = struct {
    data: []SessionCostItem,
    meta: SessionCostMeta,
};

pub fn getRankingsDaily(client: anytype, request: RankingsDailyGetRequest, request_options: options_mod.RequestOptions) !RankingsDailyGetResponse {
    return getRankingsDailyWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, request, request_options);
}

pub fn getAppRankings(client: anytype, request: AppRankingsGetRequest, request_options: options_mod.RequestOptions) !AppRankingsGetResponse {
    return getAppRankingsWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, request, request_options);
}

pub fn getBenchmarksArtificialAnalysis(client: anytype, request: BenchmarksArtificialAnalysisGetRequest, request_options: options_mod.RequestOptions) !BenchmarksArtificialAnalysisGetResponse {
    return getBenchmarksArtificialAnalysisWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, request, request_options);
}

pub fn getBenchmarksDesignArena(client: anytype, request: BenchmarksDesignArenaGetRequest, request_options: options_mod.RequestOptions) !BenchmarksDesignArenaGetResponse {
    return getBenchmarksDesignArenaWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, request, request_options);
}

pub fn getSessionCost(client: anytype, request: SessionCostRequest, request_options: options_mod.RequestOptions) !SessionCostResponse {
    return getSessionCostWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, request, request_options);
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

pub fn getAppRankingsWithTransport(
    allocator: std.mem.Allocator,
    config: config_mod.Config,
    transport: anytype,
    request: AppRankingsGetRequest,
    request_options: options_mod.RequestOptions,
) !AppRankingsGetResponse {
    const query = try appRankingsQueryString(allocator, request);
    defer allocator.free(query);

    var prepared = try http.prepareRequest(allocator, config, .{
        .method = .GET,
        .path = "/datasets/app-rankings",
        .query = query,
    }, request_options);
    defer prepared.deinit();

    var response = try transport.execute(allocator, prepared);
    defer response.deinit();

    return parseAppRankingsGetResponse(allocator, response);
}

pub fn getBenchmarksArtificialAnalysisWithTransport(
    allocator: std.mem.Allocator,
    config: config_mod.Config,
    transport: anytype,
    request: BenchmarksArtificialAnalysisGetRequest,
    request_options: options_mod.RequestOptions,
) !BenchmarksArtificialAnalysisGetResponse {
    const query = try benchmarksArtificialAnalysisQueryString(allocator, request);
    defer allocator.free(query);

    var prepared = try http.prepareRequest(allocator, config, .{
        .method = .GET,
        .path = "/datasets/benchmarks/artificial-analysis",
        .query = query,
    }, request_options);
    defer prepared.deinit();

    var response = try transport.execute(allocator, prepared);
    defer response.deinit();

    return parseBenchmarksArtificialAnalysisGetResponse(allocator, response);
}

pub fn getBenchmarksDesignArenaWithTransport(
    allocator: std.mem.Allocator,
    config: config_mod.Config,
    transport: anytype,
    request: BenchmarksDesignArenaGetRequest,
    request_options: options_mod.RequestOptions,
) !BenchmarksDesignArenaGetResponse {
    const query = try benchmarksDesignArenaQueryString(allocator, request);
    defer allocator.free(query);

    var prepared = try http.prepareRequest(allocator, config, .{
        .method = .GET,
        .path = "/datasets/benchmarks/design-arena",
        .query = query,
    }, request_options);
    defer prepared.deinit();

    var response = try transport.execute(allocator, prepared);
    defer response.deinit();

    return parseBenchmarksDesignArenaGetResponse(allocator, response);
}

pub fn getSessionCostWithTransport(
    allocator: std.mem.Allocator,
    config: config_mod.Config,
    transport: anytype,
    request: SessionCostRequest,
    request_options: options_mod.RequestOptions,
) !SessionCostResponse {
    const query = try sessionCostQueryString(allocator, request);
    defer allocator.free(query);

    var prepared = try http.prepareRequest(allocator, config, .{
        .method = .GET,
        .path = "/datasets/session-cost",
        .query = query,
    }, request_options);
    defer prepared.deinit();

    var response = try transport.execute(allocator, prepared);
    defer response.deinit();

    return parseSessionCostResponse(allocator, response);
}

pub fn parseRankingsDailyGetResponse(allocator: std.mem.Allocator, response: http.HttpResponse) !RankingsDailyGetResponse {
    if (errors.isErrorStatus(@backingInt(response.status))) return error.ApiError;

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

pub fn parseAppRankingsGetResponse(allocator: std.mem.Allocator, response: http.HttpResponse) !AppRankingsGetResponse {
    if (errors.isErrorStatus(@backingInt(response.status))) return error.ApiError;

    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const arena_allocator = arena.allocator();

    const owned_body = try arena_allocator.dupe(u8, response.body);
    const parsed = try json.parseResponseLeaky(WireAppRankingsGetResponse, arena_allocator, owned_body);
    return .{
        .arena = arena,
        .data = parsed.data,
        .meta = parsed.meta,
    };
}

pub fn parseBenchmarksArtificialAnalysisGetResponse(allocator: std.mem.Allocator, response: http.HttpResponse) !BenchmarksArtificialAnalysisGetResponse {
    if (errors.isErrorStatus(@backingInt(response.status))) return error.ApiError;

    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const arena_allocator = arena.allocator();

    const owned_body = try arena_allocator.dupe(u8, response.body);
    const parsed = try json.parseResponseLeaky(WireBenchmarksArtificialAnalysisGetResponse, arena_allocator, owned_body);
    return .{
        .arena = arena,
        .data = parsed.data,
        .meta = parsed.meta,
    };
}

pub fn parseBenchmarksDesignArenaGetResponse(allocator: std.mem.Allocator, response: http.HttpResponse) !BenchmarksDesignArenaGetResponse {
    if (errors.isErrorStatus(@backingInt(response.status))) return error.ApiError;

    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const arena_allocator = arena.allocator();

    const owned_body = try arena_allocator.dupe(u8, response.body);
    const parsed = try json.parseResponseLeaky(WireBenchmarksDesignArenaGetResponse, arena_allocator, owned_body);
    return .{
        .arena = arena,
        .data = parsed.data,
        .meta = parsed.meta,
    };
}

pub fn parseSessionCostResponse(allocator: std.mem.Allocator, response: http.HttpResponse) !SessionCostResponse {
    if (errors.isErrorStatus(@backingInt(response.status))) return error.ApiError;

    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const arena_allocator = arena.allocator();

    const owned_body = try arena_allocator.dupe(u8, response.body);
    const parsed = try json.parseResponseLeaky(WireSessionCostResponse, arena_allocator, owned_body);
    return .{
        .arena = arena,
        .data = parsed.data,
        .meta = parsed.meta,
        .response_metadata = try http.ResponseMetadata.fromHttpResponse(arena_allocator, response),
    };
}

pub fn rankingsDailyQueryString(allocator: std.mem.Allocator, request: RankingsDailyGetRequest) ![]u8 {
    return query_mod.build(allocator, &.{
        .{ .name = "start_date", .value = request.start_date },
        .{ .name = "end_date", .value = request.end_date },
    });
}

pub fn appRankingsQueryString(allocator: std.mem.Allocator, request: AppRankingsGetRequest) ![]u8 {
    const limit = if (request.limit) |value| try std.fmt.allocPrint(allocator, "{}", .{value}) else null;
    defer if (limit) |value| allocator.free(value);
    const offset = if (request.offset) |value| try std.fmt.allocPrint(allocator, "{}", .{value}) else null;
    defer if (offset) |value| allocator.free(value);

    return query_mod.build(allocator, &.{
        .{ .name = "category", .value = request.category },
        .{ .name = "subcategory", .value = request.subcategory },
        .{ .name = "sort", .value = request.sort },
        .{ .name = "start_date", .value = request.start_date },
        .{ .name = "end_date", .value = request.end_date },
        .{ .name = "limit", .value = limit },
        .{ .name = "offset", .value = offset },
    });
}

pub fn benchmarksArtificialAnalysisQueryString(allocator: std.mem.Allocator, request: BenchmarksArtificialAnalysisGetRequest) ![]u8 {
    const max_results = if (request.max_results) |value| try std.fmt.allocPrint(allocator, "{}", .{value}) else null;
    defer if (max_results) |value| allocator.free(value);

    return query_mod.build(allocator, &.{.{ .name = "max_results", .value = max_results }});
}

pub fn benchmarksDesignArenaQueryString(allocator: std.mem.Allocator, request: BenchmarksDesignArenaGetRequest) ![]u8 {
    const max_results = if (request.max_results) |value| try std.fmt.allocPrint(allocator, "{}", .{value}) else null;
    defer if (max_results) |value| allocator.free(value);

    return query_mod.build(allocator, &.{
        .{ .name = "arena", .value = request.arena },
        .{ .name = "category", .value = request.category },
        .{ .name = "max_results", .value = max_results },
    });
}

pub fn sessionCostQueryString(allocator: std.mem.Allocator, request: SessionCostRequest) ![]u8 {
    const limit = if (request.limit) |value| try std.fmt.allocPrint(allocator, "{}", .{value}) else null;
    defer if (limit) |value| allocator.free(value);
    const offset = if (request.offset) |value| try std.fmt.allocPrint(allocator, "{}", .{value}) else null;
    defer if (offset) |value| allocator.free(value);

    return query_mod.build(allocator, &.{
        .{ .name = "app_slug", .value = request.app_slug },
        .{ .name = "model", .value = request.model },
        .{ .name = "turn_range", .value = request.turn_range },
        .{ .name = "limit", .value = limit },
        .{ .name = "offset", .value = offset },
    });
}

test "session cost parses aggregates, metadata, and unknown future values" {
    const body =
        \\{
        \\  "data": [
        \\    {
        \\      "app_slug": "example-app",
        \\      "app_name": "Example App",
        \\      "turn_range": "future-turn-bucket",
        \\      "model_permaslug": "openai/gpt-4o",
        \\      "median_session_cost_usd": 0.0125,
        \\      "unknown": true
        \\    }
        \\  ],
        \\  "meta": {
        \\    "as_of": "2026-10-17T00:00:00Z",
        \\    "version": "v2",
        \\    "window_days": 7,
        \\    "window_end_date": "2026-10-16",
        \\    "unknown": true
        \\  }
        \\}
    ;

    var result = try getSessionCostWithTransport(
        std.testing.allocator,
        .{ .api_key = "test-key" },
        http.FakeTransport{
            .body = body,
            .headers = &.{.{ .name = "X-Request-ID", .value = "req_session_cost" }},
        },
        .{},
        .{},
    );
    defer result.deinit();

    try std.testing.expectEqual(@as(usize, 1), result.data.len);
    try std.testing.expectEqualStrings("future-turn-bucket", result.data[0].turn_range);
    try std.testing.expectEqual(@as(f64, 0.0125), result.data[0].median_session_cost_usd);
    try std.testing.expectEqualStrings("v2", result.meta.version);
    try std.testing.expectEqual(@as(?f64, 7), result.meta.window_days);
    try std.testing.expectEqualStrings("req_session_cost", result.response_metadata.request_id.?);
}

test "session cost accepts an empty null snapshot" {
    const body =
        \\{
        \\  "data": [],
        \\  "meta": {
        \\    "as_of": "2026-10-17T00:00:00Z",
        \\    "version": "v1",
        \\    "window_days": null,
        \\    "window_end_date": null
        \\  }
        \\}
    ;

    var result = try getSessionCostWithTransport(
        std.testing.allocator,
        .{ .api_key = "test-key" },
        http.FakeTransport{ .body = body },
        .{},
        .{},
    );
    defer result.deinit();

    try std.testing.expectEqual(@as(usize, 0), result.data.len);
    try std.testing.expectEqual(@as(?f64, null), result.meta.window_days);
    try std.testing.expectEqual(@as(?[]const u8, null), result.meta.window_end_date);
}

test "session cost rejects missing required fields including nullable metadata" {
    const missing_item_field =
        \\{
        \\  "data": [
        \\    {
        \\      "app_slug": "example-app",
        \\      "app_name": "Example App",
        \\      "turn_range": "1-turn",
        \\      "median_session_cost_usd": 0.01
        \\    }
        \\  ],
        \\  "meta": {
        \\    "as_of": "2026-10-17",
        \\    "version": "v1",
        \\    "window_days": null,
        \\    "window_end_date": null
        \\  }
        \\}
    ;
    const missing_nullable_meta_field =
        \\{
        \\  "data": [],
        \\  "meta": {
        \\    "as_of": "2026-10-17",
        \\    "version": "v1",
        \\    "window_end_date": null
        \\  }
        \\}
    ;

    try std.testing.expectError(error.MissingField, getSessionCostWithTransport(
        std.testing.allocator,
        .{ .api_key = "test-key" },
        http.FakeTransport{ .body = missing_item_field },
        .{},
        .{},
    ));

    try std.testing.expectError(error.MissingField, getSessionCostWithTransport(
        std.testing.allocator,
        .{ .api_key = "test-key" },
        http.FakeTransport{ .body = missing_nullable_meta_field },
        .{},
        .{},
    ));
}

test "session cost sends GET with all escaped query parameters" {
    const query = try sessionCostQueryString(std.testing.allocator, .{
        .app_slug = "my app&team",
        .model = "openai/gpt 4",
        .turn_range = "2-9-turns",
        .limit = 500,
        .offset = 0,
    });
    defer std.testing.allocator.free(query);

    var prepared = try http.prepareRequest(std.testing.allocator, .{ .api_key = "test-key" }, .{
        .method = .GET,
        .path = "/datasets/session-cost",
        .query = query,
    }, .{});
    defer prepared.deinit();

    try std.testing.expectEqual(std.http.Method.GET, prepared.method);
    try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/datasets/session-cost?app_slug=my%20app%26team&model=openai%2Fgpt%204&turn_range=2-9-turns&limit=500&offset=0", prepared.url);
}

test "session cost omits unset query parameters" {
    const query = try sessionCostQueryString(std.testing.allocator, .{});
    defer std.testing.allocator.free(query);

    try std.testing.expectEqualStrings("", query);
}

test "session cost maps documented error statuses to ApiError" {
    const statuses = [_]std.http.Status{
        .bad_request,
        .unauthorized,
        .too_many_requests,
        .internal_server_error,
    };

    for (statuses) |status| {
        try std.testing.expectError(error.ApiError, getSessionCostWithTransport(
            std.testing.allocator,
            .{ .api_key = "test-key" },
            http.FakeTransport{ .status = status, .body = "{\"error\":{\"message\":\"request failed\"}}" },
            .{},
            .{},
        ));
    }
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

test "app rankings get parses response and ignores unknown fields" {
    const body =
        \\{
        \\  "data": [
        \\    {
        \\      "app_id": 42,
        \\      "app_name": "Example App",
        \\      "rank": 1,
        \\      "total_requests": 123,
        \\      "total_tokens": "456789",
        \\      "unknown": true
        \\    }
        \\  ],
        \\  "meta": {
        \\    "as_of": "2026-05-12T02:00:00Z",
        \\    "end_date": "2026-05-11",
        \\    "start_date": "2026-04-12",
        \\    "version": "v1"
        \\  }
        \\}
    ;

    var result = try getAppRankingsWithTransport(std.testing.allocator, config_mod.Config{ .api_key = "test-key" }, http.FakeTransport{ .body = body }, .{}, .{});
    defer result.deinit();

    try std.testing.expectEqual(@as(usize, 1), result.data.len);
    try std.testing.expectEqual(@as(u64, 42), result.data[0].app_id);
    try std.testing.expectEqualStrings("Example App", result.data[0].app_name);
    try std.testing.expectEqualStrings("456789", result.data[0].total_tokens);
    try std.testing.expectEqualStrings("v1", result.meta.version);
}

test "app rankings get sends escaped query params" {
    const query = try appRankingsQueryString(std.testing.allocator, .{
        .category = "coding",
        .subcategory = "cli-agent",
        .sort = "trending",
        .start_date = "2026-04-12",
        .end_date = "2026-05-11",
        .limit = 25,
        .offset = 5,
    });
    defer std.testing.allocator.free(query);

    var prepared = try http.prepareRequest(std.testing.allocator, .{ .api_key = "test-key" }, .{
        .method = .GET,
        .path = "/datasets/app-rankings",
        .query = query,
    }, .{});
    defer prepared.deinit();

    try std.testing.expectEqual(std.http.Method.GET, prepared.method);
    try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/datasets/app-rankings?category=coding&subcategory=cli-agent&sort=trending&start_date=2026-04-12&end_date=2026-05-11&limit=25&offset=5", prepared.url);
}

test "artificial analysis benchmarks get parses response" {
    const body =
        \\{
        \\  "data": [
        \\    {
        \\      "aa_name": "GPT-4o mini",
        \\      "agentic_index": null,
        \\      "coding_index": 42.5,
        \\      "intelligence_index": 50.25,
        \\      "model_permaslug": "openai/gpt-4o-mini",
        \\      "pricing": { "prompt": "0.00000015", "completion": "0.0000006" }
        \\    }
        \\  ],
        \\  "meta": {
        \\    "as_of": "2026-05-12T02:00:00Z",
        \\    "citation": "Artificial Analysis",
        \\    "model_count": 1,
        \\    "source": "artificial-analysis",
        \\    "source_url": "https://artificialanalysis.ai",
        \\    "version": "2026-05-12"
        \\  }
        \\}
    ;

    var result = try getBenchmarksArtificialAnalysisWithTransport(std.testing.allocator, config_mod.Config{ .api_key = "test-key" }, http.FakeTransport{ .body = body }, .{}, .{});
    defer result.deinit();

    try std.testing.expectEqual(@as(usize, 1), result.data.len);
    try std.testing.expectEqualStrings("GPT-4o mini", result.data[0].aa_name);
    try std.testing.expectEqual(@as(?f64, 42.5), result.data[0].coding_index);
    try std.testing.expectEqualStrings("0.00000015", result.data[0].pricing.?.prompt);
    try std.testing.expectEqual(@as(u64, 1), result.meta.model_count);
}

test "artificial analysis benchmarks get sends max results query" {
    const query = try benchmarksArtificialAnalysisQueryString(std.testing.allocator, .{ .max_results = 10 });
    defer std.testing.allocator.free(query);

    var prepared = try http.prepareRequest(std.testing.allocator, .{ .api_key = "test-key" }, .{
        .method = .GET,
        .path = "/datasets/benchmarks/artificial-analysis",
        .query = query,
    }, .{});
    defer prepared.deinit();

    try std.testing.expectEqual(std.http.Method.GET, prepared.method);
    try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/datasets/benchmarks/artificial-analysis?max_results=10", prepared.url);
}

test "design arena benchmarks get parses response" {
    const body =
        \\{
        \\  "data": [
        \\    {
        \\      "arena": "models",
        \\      "avg_generation_time_ms": 1234.5,
        \\      "category": "codecategories",
        \\      "display_name": "GPT-4o mini",
        \\      "elo": 1200.25,
        \\      "model_permaslug": "openai/gpt-4o-mini",
        \\      "pricing": null,
        \\      "tournament_stats": {
        \\        "first_place": 1,
        \\        "fourth_place": null,
        \\        "second_place": 2,
        \\        "third_place": 3,
        \\        "total": 6
        \\      },
        \\      "win_rate": 55.5
        \\    }
        \\  ],
        \\  "meta": {
        \\    "arena": "models",
        \\    "as_of": "2026-05-12T02:00:00Z",
        \\    "category": null,
        \\    "citation": "Design Arena",
        \\    "elo_bounds": { "max": 1300.0, "min": 1000.0 },
        \\    "model_count": 1,
        \\    "source": "design-arena",
        \\    "source_url": "https://designarena.ai",
        \\    "version": "2026-05-12"
        \\  }
        \\}
    ;

    var result = try getBenchmarksDesignArenaWithTransport(std.testing.allocator, config_mod.Config{ .api_key = "test-key" }, http.FakeTransport{ .body = body }, .{}, .{});
    defer result.deinit();

    try std.testing.expectEqual(@as(usize, 1), result.data.len);
    try std.testing.expectEqualStrings("models", result.data[0].arena);
    try std.testing.expectEqual(@as(f64, 1200.25), result.data[0].elo);
    try std.testing.expectEqual(@as(?u64, 1), result.data[0].tournament_stats.first_place);
    try std.testing.expectEqual(@as(f64, 1300.0), result.meta.elo_bounds.max);
}

test "design arena benchmarks get sends escaped query params" {
    const query = try benchmarksDesignArenaQueryString(std.testing.allocator, .{
        .arena = "models",
        .category = "ui component",
        .max_results = 15,
    });
    defer std.testing.allocator.free(query);

    var prepared = try http.prepareRequest(std.testing.allocator, .{ .api_key = "test-key" }, .{
        .method = .GET,
        .path = "/datasets/benchmarks/design-arena",
        .query = query,
    }, .{});
    defer prepared.deinit();

    try std.testing.expectEqual(std.http.Method.GET, prepared.method);
    try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/datasets/benchmarks/design-arena?arena=models&category=ui%20component&max_results=15", prepared.url);
}

test "new dataset endpoints map error status to ApiError" {
    try std.testing.expectError(error.ApiError, getAppRankingsWithTransport(
        std.testing.allocator,
        config_mod.Config{ .api_key = "test-key" },
        http.FakeTransport{ .status = .bad_request, .body = "{\"error\":{\"message\":\"bad request\"}}" },
        .{},
        .{},
    ));
}
