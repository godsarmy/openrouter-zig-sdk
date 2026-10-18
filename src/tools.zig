//! Server-tool catalog API. These catalog types are distinct from inference tool requests.

const std = @import("std");

const config_mod = @import("config.zig");
const http = @import("http.zig");
const json = @import("json.zig");
const options_mod = @import("options.zig");
const query_mod = @import("query.zig");

pub const ApiFormat = enum {
    responses,
    @"chat-completions",
    @"anthropic-messages",
};

pub const ListRequest = struct {
    offset: ?u64 = null,
    limit: ?u64 = null,
    api_format: ?ApiFormat = null,
};

pub const GetRequest = struct {
    /// Canonical tool ID or supported input alias, not the catalog display name.
    name: []const u8,
};

/// All fields, schemas, and response metadata are arena-owned until `deinit`.
pub const ListResponse = struct {
    arena: std.heap.ArenaAllocator,
    data: []ToolCatalogTool,
    total_count: f64,
    links: ToolCatalogLinks,
    response_metadata: http.ResponseMetadata = .{},

    pub fn deinit(self: *ListResponse) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

/// All fields, schemas, and response metadata are arena-owned until `deinit`.
pub const GetResponse = struct {
    arena: std.heap.ArenaAllocator,
    data: ToolCatalogToolDetails,
    response_metadata: http.ResponseMetadata = .{},

    pub fn deinit(self: *GetResponse) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

pub const ToolCatalogLinks = struct {
    next: ?[]const u8,
};

pub const ToolCatalogTool = struct {
    id: []const u8,
    name: []const u8,
    summary: []const u8,
    tool_description: []const u8,
    status: []const u8,
    docs_url: []const u8,
    aliases: []ToolCatalogInputName,
    supported_api_formats: []const []const u8,
    default_engine: ?[]const u8,
    fallback_engine: ?[]const u8,
    parameters_schema: std.json.Value,
    input_schema: std.json.Value,
    output_schema: ?std.json.Value,
    engines: []ToolCatalogEngine,
    native_support: ToolCatalogNativeSupport,
};

pub const ToolCatalogToolDetails = struct {
    id: []const u8,
    name: []const u8,
    summary: []const u8,
    tool_description: []const u8,
    status: []const u8,
    docs_url: []const u8,
    aliases: []ToolCatalogInputName,
    supported_api_formats: []const []const u8,
    default_engine: ?[]const u8,
    fallback_engine: ?[]const u8,
    parameters_schema: std.json.Value,
    input_schema: std.json.Value,
    output_schema: ?std.json.Value,
    engines: []ToolCatalogEngine,
    native_support: ToolCatalogNativeSupportDetails,
};

pub const ToolCatalogInputName = struct {
    type: []const u8,
    api_formats: []const []const u8,
    output_names: []ToolCatalogOutputName,
};

pub const ToolCatalogOutputName = struct {
    api_format: []const u8,
    type: []const u8,
    name: ?[]const u8 = null,
};

pub const ToolCatalogEngine = struct {
    id: ?[]const u8,
    name: []const u8,
    executed_by: []const u8,
    data_regions: []const []const u8,
    byok: []const u8,
    default_mode: ?[]const u8,
    pricing_source: []const u8,
    pricing_doc_url: ?[]const u8,
    pricing: []ToolCatalogPricing,
};

pub const ToolCatalogPricing = struct {
    mode: ?[]const u8,
    unit: []const u8,
    price: []const u8,
    max_units_per_call: u64,
};

pub const ToolCatalogNativeSupport = struct {
    endpoint_count: u64,
    model_count: u64,
};

pub const ToolCatalogNativeSupportDetails = struct {
    endpoint_count: u64,
    model_count: u64,
    models: []ToolCatalogNativeModel,
};

pub const ToolCatalogNativeModel = struct {
    slug: []const u8,
    providers: []const []const u8,
};

const WireListResponse = struct {
    data: []ToolCatalogTool,
    total_count: f64,
    links: ToolCatalogLinks,
};

const WireGetResponse = struct {
    data: ToolCatalogToolDetails,
};

pub fn list(
    client: anytype,
    request: ListRequest,
    request_options: options_mod.RequestOptions,
) !ListResponse {
    return listWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, request, request_options);
}

pub fn get(
    client: anytype,
    request: GetRequest,
    request_options: options_mod.RequestOptions,
) !GetResponse {
    return getWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, request, request_options);
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
        .path = "/tools",
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
    const path = try getPath(allocator, request);
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

pub fn parseListResponse(allocator: std.mem.Allocator, response: http.HttpResponse) !ListResponse {
    if (response.status != .ok) return error.ApiError;
    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const arena_allocator = arena.allocator();
    const body = try arena_allocator.dupe(u8, response.body);
    const parsed = try json.parseResponseLeaky(WireListResponse, arena_allocator, body);
    try validateTools(parsed.data);
    return .{
        .arena = arena,
        .data = parsed.data,
        .total_count = parsed.total_count,
        .links = parsed.links,
        .response_metadata = try http.ResponseMetadata.fromHttpResponse(arena_allocator, response),
    };
}

pub fn parseGetResponse(allocator: std.mem.Allocator, response: http.HttpResponse) !GetResponse {
    if (response.status != .ok) return error.ApiError;
    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const arena_allocator = arena.allocator();
    const body = try arena_allocator.dupe(u8, response.body);
    const parsed = try json.parseResponseLeaky(WireGetResponse, arena_allocator, body);
    try validateTool(parsed.data);
    return .{
        .arena = arena,
        .data = parsed.data,
        .response_metadata = try http.ResponseMetadata.fromHttpResponse(arena_allocator, response),
    };
}

fn validateTools(tools: []const ToolCatalogTool) !void {
    for (tools) |tool| try validateTool(tool);
}

fn validateTool(tool: anytype) !void {
    if (tool.parameters_schema != .object or tool.input_schema != .object) return error.InvalidResponse;
    if (tool.output_schema) |schema| if (schema != .object) return error.InvalidResponse;
}

pub fn listQueryString(allocator: std.mem.Allocator, request: ListRequest) ![]u8 {
    const offset = if (request.offset) |value| try std.fmt.allocPrint(allocator, "{}", .{value}) else null;
    defer if (offset) |value| allocator.free(value);
    const limit = if (request.limit) |value| try std.fmt.allocPrint(allocator, "{}", .{value}) else null;
    defer if (limit) |value| allocator.free(value);
    return query_mod.build(allocator, &.{
        .{ .name = "offset", .value = offset },
        .{ .name = "limit", .value = limit },
        .{ .name = "api_format", .value = if (request.api_format) |value| @tagName(value) else null },
    });
}

pub fn getPath(allocator: std.mem.Allocator, request: GetRequest) ![]u8 {
    var path: std.ArrayList(u8) = .empty;
    errdefer path.deinit(allocator);
    try path.appendSlice(allocator, "/tools/");
    try appendPathSegment(allocator, &path, request.name);
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

test "tools list parses rich catalog data and preserves metadata" {
    const body =
        \\{
        \\  "data": [],
        \\  "total_count": 0,
        \\  "links": { "next": "cursor-next" }
        \\}
    ;
    var result = try listWithTransport(
        std.testing.allocator,
        .{ .api_key = "test-key" },
        http.FakeTransport{
            .body = body,
            .headers = &.{.{ .name = "X-Request-ID", .value = "req_tools" }},
        },
        .{},
        .{},
    );
    defer result.deinit();
    try std.testing.expectEqual(@as(usize, 0), result.data.len);
    try std.testing.expectEqualStrings("cursor-next", result.links.next.?);
    try std.testing.expectEqualStrings("req_tools", result.response_metadata.request_id.?);
}

test "tools get parses native models and requires schemas" {
    const body =
        \\{
        \\  "data": {
        \\    "id": "web",
        \\    "name": "openrouter:web",
        \\    "summary": "Web",
        \\    "tool_description": "Search",
        \\    "status": "active",
        \\    "docs_url": "https://example.test",
        \\    "aliases": [],
        \\    "supported_api_formats": ["responses"],
        \\    "default_engine": null,
        \\    "fallback_engine": null,
        \\    "parameters_schema": { "type": "object" },
        \\    "input_schema": { "type": "object" },
        \\    "output_schema": { "type": "object" },
        \\    "engines": [],
        \\    "native_support": {
        \\      "endpoint_count": 1,
        \\      "model_count": 1,
        \\      "models": [{ "slug": "openai/gpt-4o", "providers": ["openai"] }]
        \\    }
        \\  }
        \\}
    ;
    var result = try getWithTransport(
        std.testing.allocator,
        .{ .api_key = "test-key" },
        http.FakeTransport{ .body = body },
        .{ .name = "openrouter:web" },
        .{},
    );
    defer result.deinit();
    try std.testing.expectEqualStrings("openai/gpt-4o", result.data.native_support.models[0].slug);

    var missing_fields_response = try fakeResponse(std.testing.allocator, "{\"data\":{}}");
    defer missing_fields_response.deinit();
    try std.testing.expectError(error.MissingField, parseGetResponse(std.testing.allocator, missing_fields_response));
}

test "tools list query and get path escape values" {
    const query = try listQueryString(std.testing.allocator, .{ .offset = 0, .limit = 100, .api_format = .@"chat-completions" });
    defer std.testing.allocator.free(query);
    try std.testing.expectEqualStrings("offset=0&limit=100&api_format=chat-completions", query);
    const path = try getPath(std.testing.allocator, .{ .name = "alias/name: with space" });
    defer std.testing.allocator.free(path);
    try std.testing.expectEqualStrings("/tools/alias%2Fname%3A%20with%20space", path);
}

test "tools prepare exact list and get URLs" {
    const query = try listQueryString(std.testing.allocator, .{
        .offset = 0,
        .limit = 100,
        .api_format = .@"chat-completions",
    });
    defer std.testing.allocator.free(query);

    var list_prepared = try http.prepareRequest(std.testing.allocator, .{ .api_key = "test-key" }, .{
        .method = .GET,
        .path = "/tools",
        .query = query,
    }, .{});
    defer list_prepared.deinit();
    try std.testing.expectEqual(std.http.Method.GET, list_prepared.method);
    try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/tools?offset=0&limit=100&api_format=chat-completions", list_prepared.url);

    const path = try getPath(std.testing.allocator, .{ .name = "alias/name: space" });
    defer std.testing.allocator.free(path);
    var get_prepared = try http.prepareRequest(std.testing.allocator, .{ .api_key = "test-key" }, .{
        .method = .GET,
        .path = path,
    }, .{});
    defer get_prepared.deinit();
    try std.testing.expectEqual(std.http.Method.GET, get_prepared.method);
    try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/tools/alias%2Fname%3A%20space", get_prepared.url);
}

test "tools omit list query and map non-success statuses" {
    const query = try listQueryString(std.testing.allocator, .{});
    defer std.testing.allocator.free(query);
    try std.testing.expectEqualStrings("", query);
    for ([_]std.http.Status{ .unauthorized, .forbidden, .not_found, .internal_server_error, .permanent_redirect }) |status| {
        try std.testing.expectError(error.ApiError, listWithTransport(std.testing.allocator, .{ .api_key = "test-key" }, http.FakeTransport{ .status = status }, .{}, .{}));
        try std.testing.expectError(error.ApiError, getWithTransport(std.testing.allocator, .{ .api_key = "test-key" }, http.FakeTransport{ .status = status }, .{ .name = "openrouter:web" }, .{}));
    }
}

test "tools list accepts empty catalog and requires next link" {
    const empty_catalog =
        \\{
        \\  "data": [],
        \\  "total_count": 0,
        \\  "links": { "next": null }
        \\}
    ;
    var response = try fakeResponse(std.testing.allocator, empty_catalog);
    defer response.deinit();
    var result = try parseListResponse(std.testing.allocator, response);
    defer result.deinit();

    try std.testing.expectEqual(@as(usize, 0), result.data.len);
    try std.testing.expectEqual(@as(f64, 0), result.total_count);
    try std.testing.expectEqual(@as(?[]const u8, null), result.links.next);

    const missing_next =
        \\{
        \\  "data": [],
        \\  "total_count": 0,
        \\  "links": {}
        \\}
    ;
    var missing_next_response = try fakeResponse(std.testing.allocator, missing_next);
    defer missing_next_response.deinit();
    try std.testing.expectError(error.MissingField, parseListResponse(std.testing.allocator, missing_next_response));
}

test "tools detail requires native models" {
    const missing_models =
        \\{
        \\  "data": {
        \\    "id": "web",
        \\    "name": "openrouter:web",
        \\    "summary": "Web",
        \\    "tool_description": "Search",
        \\    "status": "active",
        \\    "docs_url": "https://example.test",
        \\    "aliases": [],
        \\    "supported_api_formats": [],
        \\    "default_engine": null,
        \\    "fallback_engine": null,
        \\    "parameters_schema": { "type": "object" },
        \\    "input_schema": { "type": "object" },
        \\    "output_schema": null,
        \\    "engines": [],
        \\    "native_support": { "endpoint_count": 1, "model_count": 1 }
        \\  }
        \\}
    ;
    var response = try fakeResponse(std.testing.allocator, missing_models);
    defer response.deinit();
    try std.testing.expectError(error.MissingField, parseGetResponse(std.testing.allocator, response));
}

test "tools rejects non-object schemas" {
    const template =
        \\{
        \\  "data": [{
        \\    "id": "web", "name": "openrouter:web", "summary": "Web", "tool_description": "Search",
        \\    "status": "active", "docs_url": "https://example.test", "aliases": [],
        \\    "supported_api_formats": [], "default_engine": null, "fallback_engine": null,
        \\    "parameters_schema": SCHEMA_ONE, "input_schema": SCHEMA_TWO, "output_schema": SCHEMA_THREE,
        \\    "engines": [], "native_support": { "endpoint_count": 0, "model_count": 0 }
        \\  }],
        \\  "total_count": 1,
        \\  "links": { "next": null }
        \\}
    ;

    const cases = [_]struct { one: []const u8, two: []const u8, three: []const u8 }{
        .{ .one = "1", .two = "{}", .three = "null" },
        .{ .one = "{}", .two = "1", .three = "null" },
        .{ .one = "{}", .two = "{}", .three = "1" },
    };
    for (cases) |case| {
        const one = try std.mem.replaceOwned(u8, std.testing.allocator, template, "SCHEMA_ONE", case.one);
        defer std.testing.allocator.free(one);
        const two = try std.mem.replaceOwned(u8, std.testing.allocator, one, "SCHEMA_TWO", case.two);
        defer std.testing.allocator.free(two);
        const body = try std.mem.replaceOwned(u8, std.testing.allocator, two, "SCHEMA_THREE", case.three);
        defer std.testing.allocator.free(body);

        var response = try fakeResponse(std.testing.allocator, body);
        defer response.deinit();
        try std.testing.expectError(error.InvalidResponse, parseListResponse(std.testing.allocator, response));
    }
}

fn fakeResponse(allocator: std.mem.Allocator, body: []const u8) !http.HttpResponse {
    var prepared = try http.prepareRequest(allocator, .{ .api_key = "test-key" }, .{ .method = .GET, .path = "/tools" }, .{});
    defer prepared.deinit();
    return (http.FakeTransport{ .body = body }).execute(allocator, prepared);
}
