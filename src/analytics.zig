//! Analytics API.

const std = @import("std");

const config_mod = @import("config.zig");
const errors = @import("errors.zig");
const http = @import("http.zig");
const json = @import("json.zig");
const options_mod = @import("options.zig");

pub const FilterValue = std.json.Value;
pub const Row = std.json.Value;

pub const QueryRequest = struct {
    metrics: []const []const u8,
    dimensions: ?[]const []const u8 = null,
    filters: ?[]const Filter = null,
    granularity: ?[]const u8 = null,
    group_limit: ?u64 = null,
    limit: ?u64 = null,
    order_by: ?OrderBy = null,
    time_range: ?TimeRange = null,
};

pub const Filter = struct {
    field: []const u8,
    operator: []const u8,
    value: FilterValue,
};

pub const OrderBy = struct {
    field: []const u8,
    direction: Direction,
};

pub const Direction = enum {
    asc,
    desc,
};

pub const TimeRange = struct {
    start: []const u8,
    end: []const u8,
};

pub const MetaGetResponse = struct {
    arena: std.heap.ArenaAllocator,
    data: Meta,

    pub fn deinit(self: *MetaGetResponse) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

pub const QueryResponse = struct {
    arena: std.heap.ArenaAllocator,
    data: QueryResult,

    pub fn deinit(self: *QueryResponse) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

pub const Meta = struct {
    metrics: []Metric,
    dimensions: []Dimension,
    operators: []Operator,
    granularities: []Granularity,
};

pub const Metric = struct {
    name: []const u8,
    display_label: []const u8,
    is_rate: bool,
    display_format: []const u8,
};

pub const Dimension = struct {
    name: []const u8,
    display_label: []const u8,
};

pub const Operator = struct {
    name: []const u8,
    value_type: []const u8,
};

pub const Granularity = struct {
    name: []const u8,
    display_label: []const u8,
};

pub const QueryResult = struct {
    data: []Row,
    metadata: QueryMetadata,
    cachedAt: ?f64 = null,
    warnings: ?[]const []const u8 = null,
};

pub const QueryMetadata = struct {
    query_time_ms: f64,
    row_count: u64,
    truncated: bool,
};

const WireMetaGetResponse = struct { data: Meta };
const WireQueryResponse = struct { data: QueryResult };

pub fn getMeta(client: anytype, request_options: options_mod.RequestOptions) !MetaGetResponse {
    return getMetaWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, request_options);
}

pub fn query(client: anytype, request: QueryRequest, request_options: options_mod.RequestOptions) !QueryResponse {
    return queryWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, request, request_options);
}

pub fn getMetaWithTransport(
    allocator: std.mem.Allocator,
    config: config_mod.Config,
    transport: anytype,
    request_options: options_mod.RequestOptions,
) !MetaGetResponse {
    var prepared = try http.prepareRequest(allocator, config, .{
        .method = .GET,
        .path = "/analytics/meta",
    }, request_options);
    defer prepared.deinit();

    var response = try transport.execute(allocator, prepared);
    defer response.deinit();

    return parseMetaGetResponse(allocator, response);
}

pub fn queryWithTransport(
    allocator: std.mem.Allocator,
    config: config_mod.Config,
    transport: anytype,
    request: QueryRequest,
    request_options: options_mod.RequestOptions,
) !QueryResponse {
    const body = try json.stringifyRequest(allocator, request);
    defer allocator.free(body);

    var prepared = try http.prepareRequest(allocator, config, .{
        .method = .POST,
        .path = "/analytics/query",
        .body = body,
    }, request_options);
    defer prepared.deinit();

    var response = try transport.execute(allocator, prepared);
    defer response.deinit();

    return parseQueryResponse(allocator, response);
}

pub fn parseMetaGetResponse(allocator: std.mem.Allocator, response: http.HttpResponse) !MetaGetResponse {
    if (errors.isErrorStatus(@intFromEnum(response.status))) return error.ApiError;

    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const arena_allocator = arena.allocator();

    const owned_body = try arena_allocator.dupe(u8, response.body);
    const parsed = try json.parseResponseLeaky(WireMetaGetResponse, arena_allocator, owned_body);
    return .{ .arena = arena, .data = parsed.data };
}

pub fn parseQueryResponse(allocator: std.mem.Allocator, response: http.HttpResponse) !QueryResponse {
    if (errors.isErrorStatus(@intFromEnum(response.status))) return error.ApiError;

    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const arena_allocator = arena.allocator();

    const owned_body = try arena_allocator.dupe(u8, response.body);
    const parsed = try json.parseResponseLeaky(WireQueryResponse, arena_allocator, owned_body);
    return .{ .arena = arena, .data = parsed.data };
}

test "analytics meta parses response and ignores unknown fields" {
    const body =
        \\{
        \\  "data": {
        \\    "metrics": [{"name":"request_count","display_label":"Request Count","is_rate":false,"display_format":"number","unknown":true}],
        \\    "dimensions": [{"name":"model","display_label":"Model"}],
        \\    "operators": [{"name":"eq","value_type":"scalar"}],
        \\    "granularities": [{"name":"day","display_label":"Day"}]
        \\  },
        \\  "unknown": true
        \\}
    ;

    var result = try getMetaWithTransport(std.testing.allocator, config_mod.Config{ .api_key = "test-key" }, http.FakeTransport{ .body = body }, .{});
    defer result.deinit();

    try std.testing.expectEqual(@as(usize, 1), result.data.metrics.len);
    try std.testing.expectEqualStrings("request_count", result.data.metrics[0].name);
    try std.testing.expectEqualStrings("Request Count", result.data.metrics[0].display_label);
    try std.testing.expect(!result.data.metrics[0].is_rate);
    try std.testing.expectEqualStrings("number", result.data.metrics[0].display_format);
    try std.testing.expectEqualStrings("model", result.data.dimensions[0].name);
    try std.testing.expectEqualStrings("eq", result.data.operators[0].name);
    try std.testing.expectEqualStrings("day", result.data.granularities[0].name);
}

test "analytics meta sends GET /analytics/meta" {
    var prepared = try http.prepareRequest(std.testing.allocator, .{ .api_key = "test-key" }, .{
        .method = .GET,
        .path = "/analytics/meta",
    }, .{});
    defer prepared.deinit();

    try std.testing.expectEqual(std.http.Method.GET, prepared.method);
    try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/analytics/meta", prepared.url);
}

test "analytics query stringifies request" {
    const metrics = [_][]const u8{"request_count"};
    const dimensions = [_][]const u8{"model"};
    const body = try json.stringifyRequest(std.testing.allocator, QueryRequest{
        .metrics = &metrics,
        .dimensions = &dimensions,
        .granularity = "day",
        .limit = 100,
        .time_range = .{ .start = "2025-01-01T00:00:00Z", .end = "2025-01-08T00:00:00Z" },
    });
    defer std.testing.allocator.free(body);

    try std.testing.expect(std.mem.indexOf(u8, body, "\"metrics\":") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"dimensions\":") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"granularity\":\"day\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"limit\":100") != null);
}

test "analytics query parses dynamic rows" {
    const body =
        \\{
        \\  "data": {
        \\    "data": [{"date__day":"2025-01-01T00:00:00.000Z","request_count":1500}],
        \\    "metadata": {"query_time_ms":42,"row_count":1,"truncated":false},
        \\    "warnings": ["one filter value could not be resolved"],
        \\    "cachedAt": 1735689600
        \\  }
        \\}
    ;

    var result = try queryWithTransport(std.testing.allocator, config_mod.Config{ .api_key = "test-key" }, http.FakeTransport{ .body = body }, .{ .metrics = &.{"request_count"} }, .{});
    defer result.deinit();

    try std.testing.expectEqual(@as(usize, 1), result.data.data.len);
    try std.testing.expectEqual(@as(f64, 42), result.data.metadata.query_time_ms);
    try std.testing.expectEqual(@as(u64, 1), result.data.metadata.row_count);
    try std.testing.expect(!result.data.metadata.truncated);
    try std.testing.expectEqual(@as(f64, 1735689600), result.data.cachedAt.?);
    try std.testing.expectEqualStrings("one filter value could not be resolved", result.data.warnings.?[0]);
}

test "analytics query maps error status to ApiError" {
    try std.testing.expectError(error.ApiError, queryWithTransport(
        std.testing.allocator,
        config_mod.Config{ .api_key = "test-key" },
        http.FakeTransport{ .status = .forbidden, .body = "{\"error\":{\"message\":\"management key required\"}}" },
        .{ .metrics = &.{"request_count"} },
        .{},
    ));
}
