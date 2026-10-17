//! Buffered image generation API.
//!
//! Image SSE follow-ups are not implemented. `create` always requests a
//! buffered JSON response and does not expose an unsafe `stream: true` option.

const std = @import("std");

const config_mod = @import("config.zig");
const http = @import("http.zig");
const json = @import("json.zig");
const options_mod = @import("options.zig");

pub const CreateRequest = struct {
    model: []const u8,
    prompt: []const u8,
    n: ?u32 = null,
    resolution: ?[]const u8 = null,
    aspect_ratio: ?[]const u8 = null,
    size: ?[]const u8 = null,
    quality: ?[]const u8 = null,
    output_format: ?[]const u8 = null,
    background: ?[]const u8 = null,
    output_compression: ?u32 = null,
    seed: ?i64 = null,
    input_references: ?[]const InputReference = null,
    user: ?[]const u8 = null,
    session_id: ?[]const u8 = null,
    trace: ?std.json.Value = null,
    provider: ?std.json.Value = null,
};

pub const InputReference = struct {
    type: []const u8 = "image_url",
    image_url: ImageUrl,
};

pub const ImageUrl = struct { url: []const u8 };

const CreateBody = struct {
    model: []const u8,
    prompt: []const u8,
    stream: bool = false,
    n: ?u32 = null,
    resolution: ?[]const u8 = null,
    aspect_ratio: ?[]const u8 = null,
    size: ?[]const u8 = null,
    quality: ?[]const u8 = null,
    output_format: ?[]const u8 = null,
    background: ?[]const u8 = null,
    output_compression: ?u32 = null,
    seed: ?i64 = null,
    input_references: ?[]const InputReference = null,
    user: ?[]const u8 = null,
    session_id: ?[]const u8 = null,
    trace: ?std.json.Value = null,
    provider: ?std.json.Value = null,
};

pub const CreateResponse = struct {
    arena: std.heap.ArenaAllocator,
    response_metadata: http.ResponseMetadata = .{},
    created: i64,
    data: []GeneratedImage,
    usage: ?Usage = null,
    /// The complete response object, including additive fields.
    raw: std.json.Value,

    pub fn deinit(self: *CreateResponse) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

pub const GeneratedImage = struct {
    b64_json: []const u8,
    media_type: ?[]const u8 = null,
};

pub const Usage = struct {
    prompt_tokens: ?u64 = null,
    completion_tokens: ?u64 = null,
    total_tokens: ?u64 = null,
    /// Present `null` costs remain null.
    cost: ?f64 = null,
    raw: std.json.Value = .null,
};

pub const ModelsListResponse = struct {
    arena: std.heap.ArenaAllocator,
    response_metadata: http.ResponseMetadata = .{},
    data: []Model,
    raw: std.json.Value,

    pub fn deinit(self: *ModelsListResponse) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

pub const Model = struct {
    id: []const u8,
    name: []const u8,
    description: []const u8,
    created: i64,
    architecture: Architecture,
    /// An object mapping parameter names to capability descriptors. Descriptor
    /// variants (`values`, `range`, `boolean`, and future variants) are kept raw.
    supported_parameters: std.json.Value,
    supports_streaming: bool,
    endpoints: []const u8,
};

pub const Architecture = struct {
    input_modalities: []const []const u8,
    output_modalities: []const []const u8,
};

pub const ListModelEndpointsRequest = struct {
    author: []const u8,
    slug: []const u8,
};

pub const ModelEndpointsResponse = struct {
    arena: std.heap.ArenaAllocator,
    response_metadata: http.ResponseMetadata = .{},
    id: []const u8,
    endpoints: []Endpoint,
    raw: std.json.Value,

    pub fn deinit(self: *ModelEndpointsResponse) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

pub const Endpoint = struct {
    provider_name: []const u8,
    provider_slug: []const u8,
    provider_tag: ?[]const u8,
    supported_parameters: std.json.Value,
    allowed_passthrough_parameters: []const []const u8,
    supports_streaming: bool,
    pricing: []Pricing,
};

pub const Pricing = struct {
    billable: []const u8,
    unit: []const u8,
    cost_usd: f64,
    variant: ?[]const u8 = null,
};

const WireCreateResponse = struct { created: i64, data: []GeneratedImage, usage: ?Usage = null };
const WireModelsListResponse = struct { data: []Model };
const WireModelEndpointsResponse = struct { id: []const u8, endpoints: []Endpoint };

pub fn create(client: anytype, request: CreateRequest, request_options: options_mod.RequestOptions) !CreateResponse {
    return createWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, request, request_options);
}

pub fn createWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, request: CreateRequest, request_options: options_mod.RequestOptions) !CreateResponse {
    const body = try json.stringifyRequest(allocator, CreateBody{
        .model = request.model,
        .prompt = request.prompt,
        .n = request.n,
        .resolution = request.resolution,
        .aspect_ratio = request.aspect_ratio,
        .size = request.size,
        .quality = request.quality,
        .output_format = request.output_format,
        .background = request.background,
        .output_compression = request.output_compression,
        .seed = request.seed,
        .input_references = request.input_references,
        .user = request.user,
        .session_id = request.session_id,
        .trace = request.trace,
        .provider = request.provider,
    });
    defer allocator.free(body);
    var prepared = try http.prepareRequest(allocator, config, .{ .method = .POST, .path = "/images", .body = body }, request_options);
    defer prepared.deinit();
    var response = try transport.execute(allocator, prepared);
    defer response.deinit();
    return parseCreateResponse(allocator, response);
}

pub fn listModels(client: anytype, request_options: options_mod.RequestOptions) !ModelsListResponse {
    return listModelsWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, request_options);
}

pub fn listModelsWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, request_options: options_mod.RequestOptions) !ModelsListResponse {
    var prepared = try http.prepareRequest(allocator, config, .{ .method = .GET, .path = "/images/models" }, request_options);
    defer prepared.deinit();
    var response = try transport.execute(allocator, prepared);
    defer response.deinit();
    return parseModelsListResponse(allocator, response);
}

pub fn listModelEndpoints(client: anytype, request: ListModelEndpointsRequest, request_options: options_mod.RequestOptions) !ModelEndpointsResponse {
    return listModelEndpointsWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, request, request_options);
}

pub fn listModelEndpointsWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, request: ListModelEndpointsRequest, request_options: options_mod.RequestOptions) !ModelEndpointsResponse {
    const path = try modelEndpointsPath(allocator, request);
    defer allocator.free(path);
    var prepared = try http.prepareRequest(allocator, config, .{ .method = .GET, .path = path }, request_options);
    defer prepared.deinit();
    var response = try transport.execute(allocator, prepared);
    defer response.deinit();
    return parseModelEndpointsResponse(allocator, response);
}

pub fn parseCreateResponse(allocator: std.mem.Allocator, response: http.HttpResponse) !CreateResponse {
    if (response.status != .ok) return error.ApiError;
    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const a = arena.allocator();
    const body = try a.dupe(u8, response.body);
    var parsed = try json.parseResponseLeaky(WireCreateResponse, a, body);
    const raw = try json.parseResponseLeaky(std.json.Value, a, body);
    if (parsed.usage) |*usage| usage.raw = try usageValue(raw);
    return .{ .arena = arena, .response_metadata = try http.ResponseMetadata.fromHttpResponse(a, response), .created = parsed.created, .data = parsed.data, .usage = parsed.usage, .raw = raw };
}

pub fn parseModelsListResponse(allocator: std.mem.Allocator, response: http.HttpResponse) !ModelsListResponse {
    if (response.status != .ok) return error.ApiError;
    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const a = arena.allocator();
    const body = try a.dupe(u8, response.body);
    const parsed = try json.parseResponseLeaky(WireModelsListResponse, a, body);
    for (parsed.data) |model| try requireObject(model.supported_parameters);
    return .{ .arena = arena, .response_metadata = try http.ResponseMetadata.fromHttpResponse(a, response), .data = parsed.data, .raw = try json.parseResponseLeaky(std.json.Value, a, body) };
}

pub fn parseModelEndpointsResponse(allocator: std.mem.Allocator, response: http.HttpResponse) !ModelEndpointsResponse {
    if (response.status != .ok) return error.ApiError;
    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const a = arena.allocator();
    const body = try a.dupe(u8, response.body);
    const parsed = try json.parseResponseLeaky(WireModelEndpointsResponse, a, body);
    for (parsed.endpoints) |endpoint| try requireObject(endpoint.supported_parameters);
    return .{ .arena = arena, .response_metadata = try http.ResponseMetadata.fromHttpResponse(a, response), .id = parsed.id, .endpoints = parsed.endpoints, .raw = try json.parseResponseLeaky(std.json.Value, a, body) };
}

fn usageValue(raw: std.json.Value) !std.json.Value {
    const object = objectValue(raw) orelse return error.UnexpectedToken;
    return object.get("usage") orelse .null;
}

fn requireObject(value: std.json.Value) !void {
    if (objectValue(value) == null) return error.UnexpectedToken;
}
fn objectValue(value: std.json.Value) ?std.json.ObjectMap {
    return if (value == .object) value.object else null;
}

fn modelEndpointsPath(allocator: std.mem.Allocator, request: ListModelEndpointsRequest) ![]u8 {
    var path: std.ArrayList(u8) = .empty;
    errdefer path.deinit(allocator);
    try path.appendSlice(allocator, "/images/models/");
    try appendPathSegment(allocator, &path, request.author);
    try path.append(allocator, '/');
    try appendPathSegment(allocator, &path, request.slug);
    try path.appendSlice(allocator, "/endpoints");
    return path.toOwnedSlice(allocator);
}

fn appendPathSegment(allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: []const u8) !void {
    const hex = "0123456789ABCDEF";
    for (value) |byte| if (std.ascii.isAlphanumeric(byte) or byte == '-' or byte == '_' or byte == '.' or byte == '~') try output.append(allocator, byte) else try output.appendSlice(allocator, &.{ '%', hex[byte >> 4], hex[byte & 15] });
}

const RecordingTransport = struct {
    body: []const u8,
    method: ?std.http.Method = null,
    url: ?[]u8 = null,
    request_body: ?[]u8 = null,
    custom_header: ?[]u8 = null,

    fn deinit(self: *RecordingTransport, allocator: std.mem.Allocator) void {
        if (self.url) |value| allocator.free(value);
        if (self.request_body) |value| allocator.free(value);
        if (self.custom_header) |value| allocator.free(value);
    }

    fn execute(self: *RecordingTransport, allocator: std.mem.Allocator, prepared: http.PreparedRequest) !http.HttpResponse {
        self.method = prepared.method;
        self.url = try allocator.dupe(u8, prepared.url);
        if (prepared.body) |value| self.request_body = try allocator.dupe(u8, value);
        for (prepared.headers) |header| {
            if (std.mem.eql(u8, header.name, "X-Test")) {
                self.custom_header = try allocator.dupe(u8, header.value);
            }
        }
        return .{ .allocator = allocator, .status = .ok, .body = try allocator.dupe(u8, self.body) };
    }
};

test "images parses rich create response and preserves base64 media type" {
    var result = try createWithTransport(std.testing.allocator, .{ .api_key = "key" }, http.FakeTransport{ .body =
        \\{"created":123,"data":[{"b64_json":"aGVsbG8=","media_type":"image/webp"}],"usage":{"prompt_tokens":0,"completion_tokens":2,"total_tokens":2,"cost":null,"future":true},"future":"kept"}
    }, .{ .model = "image/model", .prompt = "hello" }, .{});
    defer result.deinit();
    try std.testing.expectEqual(@as(i64, 123), result.created);
    try std.testing.expectEqualStrings("aGVsbG8=", result.data[0].b64_json);
    try std.testing.expectEqualStrings("image/webp", result.data[0].media_type.?);
    try std.testing.expectEqual(@as(?f64, null), result.usage.?.cost);
}

test "images optional metadata accepts null and empty values" {
    var result = try createWithTransport(std.testing.allocator, .{ .api_key = "key" }, http.FakeTransport{ .body = "{\"created\":0,\"data\":[{\"b64_json\":\"\",\"media_type\":null}]}" }, .{ .model = "m", .prompt = "p" }, .{});
    defer result.deinit();
    try std.testing.expect(result.data[0].media_type == null);
}

test "images rejects malformed required response schema" {
    try std.testing.expectError(error.MissingField, createWithTransport(std.testing.allocator, .{ .api_key = "key" }, http.FakeTransport{ .body = "{\"created\":1}" }, .{ .model = "m", .prompt = "p" }, .{}));
}

test "images serializes every optional value including false and zero" {
    var parsed_provider = try json.parseResponse(std.json.Value, std.testing.allocator, "false");
    defer parsed_provider.deinit();
    const provider = parsed_provider.value;
    const body = try json.stringifyRequest(std.testing.allocator, CreateBody{ .model = "m", .prompt = "p", .n = 0, .resolution = "", .aspect_ratio = "", .size = "", .quality = "", .output_format = "", .background = "", .output_compression = 0, .seed = 0, .input_references = &.{.{ .image_url = .{ .url = "https://example.test/a.png" } }}, .user = "", .session_id = "", .trace = provider, .provider = provider });
    defer std.testing.allocator.free(body);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"stream\":false") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"output_compression\":0") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"provider\":false") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"input_references\"") != null);
}

test "images methods use exact URLs and POST carries body and headers" {
    const create_body = "{\"created\":0,\"data\":[{\"b64_json\":\"x\"}]}";
    var create_transport = RecordingTransport{ .body = create_body };
    defer create_transport.deinit(std.testing.allocator);
    var created = try createWithTransport(std.testing.allocator, .{ .api_key = "key" }, &create_transport, .{ .model = "m", .prompt = "p" }, .{ .extra_headers = &.{.{ .name = "X-Test", .value = "yes" }} });
    defer created.deinit();
    try std.testing.expectEqual(std.http.Method.POST, create_transport.method.?);
    try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/images", create_transport.url.?);
    try std.testing.expect(std.mem.indexOf(u8, create_transport.request_body.?, "\"stream\":false") != null);
    try std.testing.expectEqualStrings("yes", create_transport.custom_header.?);

    var models_transport = RecordingTransport{ .body = "{\"data\":[]}" };
    defer models_transport.deinit(std.testing.allocator);
    var models = try listModelsWithTransport(std.testing.allocator, .{ .api_key = "key" }, &models_transport, .{});
    defer models.deinit();
    try std.testing.expectEqual(std.http.Method.GET, models_transport.method.?);
    try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/images/models", models_transport.url.?);

    var endpoints_transport = RecordingTransport{ .body = "{\"id\":\"m\",\"endpoints\":[]}" };
    defer endpoints_transport.deinit(std.testing.allocator);
    var endpoints = try listModelEndpointsWithTransport(std.testing.allocator, .{ .api_key = "key" }, &endpoints_transport, .{ .author = "author", .slug = "model" }, .{});
    defer endpoints.deinit();
    try std.testing.expectEqual(std.http.Method.GET, endpoints_transport.method.?);
    try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/images/models/author/model/endpoints", endpoints_transport.url.?);
}

test "images model capabilities retain future descriptors" {
    var result = try listModelsWithTransport(std.heap.page_allocator, .{ .api_key = "key" }, http.FakeTransport{ .body =
        \\{"data":[{"id":"m","name":"M","description":"d","created":1,"architecture":{"input_modalities":["text"],"output_modalities":["image"]},"supported_parameters":{"quality":{"future_kind":[1]}},"supports_streaming":false,"endpoints":"/x"}]}
    }, .{});
    defer result.deinit();
    try std.testing.expect(result.data[0].supported_parameters == .object);
}

test "images endpoint path encodes reserved author and slug segments" {
    const path = try modelEndpointsPath(std.testing.allocator, .{ .author = "a/b", .slug = "s? x" });
    defer std.testing.allocator.free(path);
    try std.testing.expectEqualStrings("/images/models/a%2Fb/s%3F%20x/endpoints", path);
}

test "images maps non-200 responses to ApiError" {
    try std.testing.expectError(error.ApiError, listModelsWithTransport(std.testing.allocator, .{ .api_key = "key" }, http.FakeTransport{ .status = .bad_request }, .{}));
}

test "images require HTTP 200 for every operation" {
    const create_request = CreateRequest{ .model = "m", .prompt = "p" };
    const endpoints_request = ListModelEndpointsRequest{ .author = "author", .slug = "model" };
    for ([_]std.http.Status{ .created, .accepted, .permanent_redirect }) |status| {
        try std.testing.expectError(error.ApiError, createWithTransport(std.testing.allocator, .{ .api_key = "key" }, http.FakeTransport{ .status = status }, create_request, .{}));
        try std.testing.expectError(error.ApiError, listModelsWithTransport(std.testing.allocator, .{ .api_key = "key" }, http.FakeTransport{ .status = status }, .{}));
        try std.testing.expectError(error.ApiError, listModelEndpointsWithTransport(std.testing.allocator, .{ .api_key = "key" }, http.FakeTransport{ .status = status }, endpoints_request, .{}));
    }
}

test "images endpoint response preserves raw capabilities and metadata" {
    const body =
        \\{
        \\  "id": "author/model",
        \\  "endpoints": [{
        \\    "provider_name": "Provider",
        \\    "provider_slug": "provider",
        \\    "provider_tag": null,
        \\    "supported_parameters": {
        \\      "quality": { "future_variant": "experimental", "values": ["fast"] }
        \\    },
        \\    "allowed_passthrough_parameters": ["future_mode", "seed"],
        \\    "supports_streaming": false,
        \\    "pricing": [{
        \\      "billable": "image",
        \\      "unit": "image",
        \\      "cost_usd": 0.04,
        \\      "variant": "future-tier"
        \\    }],
        \\    "future_enum_string": "new-value"
        \\  }],
        \\  "future_top_level": "preserved"
        \\}
    ;
    var result = try listModelEndpointsWithTransport(
        std.heap.page_allocator,
        .{ .api_key = "key" },
        http.FakeTransport{ .body = body, .headers = &.{.{ .name = "X-Request-ID", .value = "req_images" }} },
        .{ .author = "author", .slug = "model" },
        .{},
    );
    defer result.deinit();

    const endpoint = result.endpoints[0];
    try std.testing.expect(endpoint.provider_tag == null);
    try std.testing.expect(endpoint.supported_parameters == .object);
    try std.testing.expectEqualStrings("future_mode", endpoint.allowed_passthrough_parameters[0]);
    try std.testing.expectEqual(@as(f64, 0.04), endpoint.pricing[0].cost_usd);
    try std.testing.expectEqualStrings("future-tier", endpoint.pricing[0].variant.?);
    try std.testing.expectEqualStrings("req_images", result.response_metadata.request_id.?);
    try std.testing.expect(result.raw == .object);
    try std.testing.expect(result.raw.object.get("future_top_level") != null);
}

test "images reject scalar capability maps consistently" {
    const model_body =
        \\{"data":[{"id":"m","name":"M","description":"d","created":1,"architecture":{"input_modalities":["text"],"output_modalities":["image"]},"supported_parameters":"invalid","supports_streaming":false,"endpoints":"/x"}]}
    ;
    const endpoints_body =
        \\{"id":"m","endpoints":[{"provider_name":"p","provider_slug":"p","provider_tag":null,"supported_parameters":false,"allowed_passthrough_parameters":[],"supports_streaming":false,"pricing":[]}]}
    ;
    try std.testing.expectError(error.UnexpectedToken, listModelsWithTransport(std.testing.allocator, .{ .api_key = "key" }, http.FakeTransport{ .body = model_body }, .{}));
    try std.testing.expectError(error.UnexpectedToken, listModelEndpointsWithTransport(std.testing.allocator, .{ .api_key = "key" }, http.FakeTransport{ .body = endpoints_body }, .{ .author = "a", .slug = "m" }, .{}));
}
