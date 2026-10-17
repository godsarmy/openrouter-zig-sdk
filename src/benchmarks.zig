//! Unified benchmarks API.

const std = @import("std");

const config_mod = @import("config.zig");
const errors = @import("errors.zig");
const http = @import("http.zig");
const json = @import("json.zig");
const options_mod = @import("options.zig");
const query_mod = @import("query.zig");

pub const Source = enum {
    @"artificial-analysis",
    @"design-arena",
    openrouter,
};

pub const TaskType = enum {
    coding,
    intelligence,
    agentic,
    search,
};
pub const BenchmarkType = enum {
    gpqa_diamond,
    tau_bench_verified_airline,
    search_browsecomp,
    search_hle,
    search_dsqa,
    search_widesearch,
};
pub const SearchSurface = enum {
    @"server-tool",
    plugin,
};

pub const ListRequest = struct {
    source: ?Source = null,
    task_type: ?TaskType = null,
    benchmark_type: ?BenchmarkType = null,
    include_run_config: ?bool = null,
    search_engine: ?[]const u8 = null,
    search_surface: ?SearchSurface = null,
    arena: ?[]const u8 = null,
    category: ?[]const u8 = null,
    max_results: ?u64 = null,
};

pub const Pricing = struct {
    prompt: []const u8,
    completion: []const u8,
};

pub const ArtificialAnalysisItem = struct {
    source: []const u8,
    model_permaslug: []const u8,
    display_name: []const u8,
    intelligence_index: ?f64 = null,
    coding_index: ?f64 = null,
    agentic_index: ?f64 = null,
    pricing: ?Pricing = null,
};

pub const TournamentStats = struct {
    first_place: ?u64 = null,
    second_place: ?u64 = null,
    third_place: ?u64 = null,
    fourth_place: ?u64 = null,
    total: ?u64 = null,
};

pub const DesignArenaItem = struct {
    source: []const u8,
    model_permaslug: []const u8,
    display_name: []const u8,
    arena: []const u8,
    category: []const u8,
    elo: f64,
    win_rate: f64,
    avg_generation_time_ms: ?f64 = null,
    tournament_stats: TournamentStats,
    pricing: ?Pricing = null,
};

pub const OpenRouterClassicItem = struct {
    source: []const u8,
    model_permaslug: []const u8,
    display_name: []const u8,
    benchmark_type: []const u8,
    accuracy: f64,
    accuracy_stddev: ?f64 = null,
    avg_cost_per_task: ?f64 = null,
    total_tasks: u64,
    last_run_timestamp: []const u8,
};

pub const RunConfig = struct {
    max_agent_turns: ?u64 = null,
    reasoning_effort: ?[]const u8 = null,
    temperature: ?f64 = null,
};

pub const OpenRouterSearchItem = struct {
    source: []const u8,
    model_permaslug: []const u8,
    display_name: []const u8,
    benchmark_type: []const u8,
    primary_metric: []const u8,
    primary_score: f64,
    total_tasks: u64,
    avg_cost_per_task: f64,
    avg_latency_per_task_ms: f64,
    search_engine: []const u8,
    search_surface: []const u8,
    last_run_timestamp: []const u8,
    run_config: ?RunConfig = null,
};

/// Unknown variants retain their raw JSON value. It and all other fields are owned by the response arena.
pub const Item = union(enum) {
    artificial_analysis: ArtificialAnalysisItem,
    design_arena: DesignArenaItem,
    openrouter_classic: OpenRouterClassicItem,
    openrouter_search: OpenRouterSearchItem,
    unknown: std.json.Value,
};

pub const Meta = struct {
    as_of: []const u8,
    version: []const u8,
    source: ?[]const u8,
    source_url: ?[]const u8,
    citation: ?[]const u8,
    model_count: u64,
    task_type: ?[]const u8,
};

pub const ListResponse = struct {
    arena: std.heap.ArenaAllocator,
    data: []Item,
    meta: Meta,
    response_metadata: http.ResponseMetadata = .{},

    pub fn deinit(self: *ListResponse) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

const Wire = struct {
    data: []std.json.Value,
    meta: Meta,
};

pub fn list(client: anytype, request: ListRequest, request_options: options_mod.RequestOptions) !ListResponse {
    return listWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, request, request_options);
}

pub fn listWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, request: ListRequest, request_options: options_mod.RequestOptions) !ListResponse {
    const query = try queryString(allocator, request);
    defer allocator.free(query);

    var prepared = try http.prepareRequest(allocator, config, .{ .method = .GET, .path = "/benchmarks", .query = query }, request_options);
    defer prepared.deinit();

    var response = try transport.execute(allocator, prepared);
    defer response.deinit();

    return parseListResponse(allocator, response);
}

pub fn parseListResponse(allocator: std.mem.Allocator, response: http.HttpResponse) !ListResponse {
    if (errors.isErrorStatus(@backingInt(response.status))) return error.ApiError;

    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const arena_allocator = arena.allocator();

    const body = try arena_allocator.dupe(u8, response.body);
    const wire = try json.parseResponseLeaky(Wire, arena_allocator, body);
    var items: std.ArrayList(Item) = .empty;
    for (wire.data) |value| try items.append(arena_allocator, try parseItem(arena_allocator, value));

    return .{
        .arena = arena,
        .data = try items.toOwnedSlice(arena_allocator),
        .meta = wire.meta,
        .response_metadata = try http.ResponseMetadata.fromHttpResponse(arena_allocator, response),
    };
}

fn parseItem(allocator: std.mem.Allocator, value: std.json.Value) !Item {
    const object = if (value == .object) value.object else return .{ .unknown = value };
    const source = object.get("source") orelse return .{ .unknown = value };
    if (source != .string) return .{ .unknown = value };
    if (std.mem.eql(u8, source.string, "artificial-analysis")) {
        return .{ .artificial_analysis = try parseValue(ArtificialAnalysisItem, allocator, value) };
    }
    if (std.mem.eql(u8, source.string, "design-arena")) {
        return .{ .design_arena = try parseValue(DesignArenaItem, allocator, value) };
    }
    if (!std.mem.eql(u8, source.string, "openrouter")) return .{ .unknown = value };
    if (object.get("primary_metric") != null) {
        return .{ .openrouter_search = try parseValue(OpenRouterSearchItem, allocator, value) };
    }
    const benchmark_type = object.get("benchmark_type") orelse return .{ .unknown = value };
    if (benchmark_type != .string) return .{ .unknown = value };
    if (std.mem.startsWith(u8, benchmark_type.string, "gpqa_") or
        std.mem.startsWith(u8, benchmark_type.string, "tau_bench_"))
    {
        return .{ .openrouter_classic = try parseValue(OpenRouterClassicItem, allocator, value) };
    }
    return .{ .unknown = value };
}

fn parseValue(comptime T: type, allocator: std.mem.Allocator, value: std.json.Value) !T {
    var writer: std.Io.Writer.Allocating = .init(allocator);
    defer writer.deinit();
    try std.json.Stringify.value(value, .{}, &writer.writer);
    return json.parseResponseLeaky(T, allocator, writer.written());
}

pub fn queryString(allocator: std.mem.Allocator, request: ListRequest) ![]u8 {
    var max_results_buffer: [20]u8 = undefined;
    const max_results = if (request.max_results) |value|
        try std.fmt.bufPrint(&max_results_buffer, "{d}", .{value})
    else
        null;
    return query_mod.build(allocator, &.{
        .{ .name = "source", .value = enumValue(request.source) },
        .{ .name = "task_type", .value = enumValue(request.task_type) },
        .{ .name = "benchmark_type", .value = enumValue(request.benchmark_type) },
        .{
            .name = "include_run_config",
            .value = if (request.include_run_config) |value|
                if (value) "true" else "false"
            else
                null,
        },
        .{ .name = "search_engine", .value = request.search_engine },
        .{ .name = "search_surface", .value = enumValue(request.search_surface) },
        .{ .name = "arena", .value = request.arena },
        .{ .name = "category", .value = request.category },
        .{ .name = "max_results", .value = max_results },
    });
}

fn enumValue(value: anytype) ?[]const u8 {
    return if (value) |item| @tagName(item) else null;
}

test "benchmarks list parses variants and preserves unknown values" {
    const body =
        \\{
        \\  "data": [
        \\    {
        \\      "source": "artificial-analysis",
        \\      "model_permaslug": "a",
        \\      "display_name": "A",
        \\      "intelligence_index": null
        \\    },
        \\    {
        \\      "source": "design-arena",
        \\      "model_permaslug": "d",
        \\      "display_name": "D",
        \\      "arena": "models",
        \\      "category": "all",
        \\      "elo": 1,
        \\      "win_rate": 2,
        \\      "tournament_stats": {}
        \\    },
        \\    {
        \\      "source": "openrouter",
        \\      "model_permaslug": "c",
        \\      "display_name": "C",
        \\      "benchmark_type": "gpqa_diamond",
        \\      "accuracy": 1,
        \\      "total_tasks": 1,
        \\      "last_run_timestamp": "now"
        \\    },
        \\    {
        \\      "source": "openrouter",
        \\      "model_permaslug": "s",
        \\      "display_name": "S",
        \\      "benchmark_type": "search_hle",
        \\      "primary_metric": "score",
        \\      "primary_score": 1,
        \\      "total_tasks": 1,
        \\      "avg_cost_per_task": 1,
        \\      "avg_latency_per_task_ms": 1,
        \\      "search_engine": "x",
        \\      "search_surface": "plugin",
        \\      "last_run_timestamp": "now"
        \\    },
        \\    {
        \\      "source": "future",
        \\      "x": 1
        \\    },
        \\    {
        \\      "source": "openrouter",
        \\      "benchmark_type": "future"
        \\    }
        \\  ],
        \\  "meta": {
        \\    "as_of": "now",
        \\    "version": "1",
        \\    "source": null,
        \\    "source_url": null,
        \\    "citation": null,
        \\    "model_count": 6,
        \\    "task_type": null
        \\  }
        \\}
    ;
    var result = try listWithTransport(
        std.testing.allocator,
        .{ .api_key = "test" },
        http.FakeTransport{ .body = body },
        .{},
        .{},
    );
    defer result.deinit();
    try std.testing.expectEqual(@as(usize, 6), result.data.len);
    try std.testing.expect(result.data[0] == .artificial_analysis);
    try std.testing.expect(result.data[1] == .design_arena);
    try std.testing.expect(result.data[2] == .openrouter_classic);
    try std.testing.expect(result.data[3] == .openrouter_search);
    try std.testing.expect(result.data[4] == .unknown);
    try std.testing.expectEqual(null, result.meta.citation);
}

test "benchmarks list sends encoded optional query and omits defaults" {
    const absent = try queryString(std.testing.allocator, .{});
    defer std.testing.allocator.free(absent);
    try std.testing.expectEqualStrings("", absent);
    const query = try queryString(std.testing.allocator, .{
        .source = .@"artificial-analysis",
        .include_run_config = false,
        .search_engine = "a/b c",
        .search_surface = .@"server-tool",
        .max_results = 1,
    });
    defer std.testing.allocator.free(query);
    try std.testing.expectEqualStrings("source=artificial-analysis&include_run_config=false&search_engine=a%2Fb%20c&search_surface=server-tool&max_results=1", query);

    var prepared = try http.prepareRequest(std.testing.allocator, .{ .api_key = "test" }, .{
        .method = .GET,
        .path = "/benchmarks",
        .query = query,
    }, .{});
    defer prepared.deinit();
    try std.testing.expectEqual(std.http.Method.GET, prepared.method);
    try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/benchmarks?source=artificial-analysis&include_run_config=false&search_engine=a%2Fb%20c&search_surface=server-tool&max_results=1", prepared.url);
}

test "benchmarks list supports empty arrays and errors" {
    const body =
        \\{
        \\  "data": [],
        \\  "meta": { "as_of": "now", "version": "1", "source": null, "source_url": null, "citation": null, "model_count": 0, "task_type": null }
        \\}
    ;
    var result = try listWithTransport(
        std.testing.allocator,
        .{ .api_key = "test" },
        http.FakeTransport{ .body = body },
        .{},
        .{},
    );
    defer result.deinit();
    try std.testing.expectEqual(@as(usize, 0), result.data.len);
    try std.testing.expectError(error.ApiError, listWithTransport(
        std.testing.allocator,
        .{ .api_key = "test" },
        http.FakeTransport{ .status = .internal_server_error },
        .{},
        .{},
    ));

    const missing_fields_body =
        \\{
        \\  "data": [{ "source": "artificial-analysis" }],
        \\  "meta": { "as_of": "now", "version": "1", "source": null, "source_url": null, "citation": null, "model_count": 1, "task_type": null }
        \\}
    ;
    try std.testing.expectError(error.MissingField, listWithTransport(
        std.testing.allocator,
        .{ .api_key = "test" },
        http.FakeTransport{ .body = missing_fields_body },
        .{},
        .{},
    ));
}
