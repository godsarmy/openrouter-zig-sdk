//! Generation metadata API.

const std = @import("std");

const config_mod = @import("config.zig");
const errors = @import("errors.zig");
const http = @import("http.zig");
const json = @import("json.zig");
const options_mod = @import("options.zig");
const query_mod = @import("query.zig");

pub const GetRequest = struct {
    id: []const u8,
};

pub const GetResponse = struct {
    arena: std.heap.ArenaAllocator,
    data: Generation,

    pub fn deinit(self: *GetResponse) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

pub const ContentRequest = struct {
    id: []const u8,
};

pub const ContentResponse = struct {
    arena: std.heap.ArenaAllocator,
    data: GenerationContent,

    pub fn deinit(self: *ContentResponse) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

pub const FeedbackCategory = enum {
    latency,
    incoherence,
    incorrect_response,
    formatting,
    billing,
    api_error,
    other,
};

pub const FeedbackRequest = struct {
    generation_id: []const u8,
    category: FeedbackCategory,
    comment: ?[]const u8 = null,
};

/// The response and its metadata are owned until `deinit`.
pub const FeedbackResponse = struct {
    arena: std.heap.ArenaAllocator,
    data: FeedbackData,
    response_metadata: http.ResponseMetadata = .{},

    pub fn deinit(self: *FeedbackResponse) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

pub const FeedbackData = struct {
    success: bool,
};

pub const Generation = struct {
    api_type: ?[]const u8,
    app_id: ?u64,
    cache_discount: ?f64,
    cancelled: ?bool,
    created_at: []const u8,
    external_user: ?[]const u8,
    finish_reason: ?[]const u8,
    generation_time: ?f64,
    http_referer: ?[]const u8,
    id: []const u8,
    is_byok: bool,
    latency: ?f64,
    model: []const u8,
    moderation_latency: ?f64,
    native_finish_reason: ?[]const u8,
    native_tokens_cached: ?u64,
    native_tokens_completion: ?u64,
    native_tokens_completion_images: ?u64,
    native_tokens_prompt: ?u64,
    native_tokens_reasoning: ?u64,
    num_fetches: ?u64,
    num_input_audio_prompt: ?u64,
    num_media_completion: ?u64,
    num_media_prompt: ?u64,
    num_search_results: ?u64,
    origin: []const u8,
    preset_id: ?[]const u8,
    provider_name: ?[]const u8,
    provider_responses: ?[]ProviderResponse,
    request_id: ?[]const u8,
    response_cache_source_id: ?[]const u8,
    router: ?[]const u8,
    service_tier: ?[]const u8,
    session_id: ?[]const u8,
    streamed: ?bool,
    tokens_completion: ?u64,
    tokens_prompt: ?u64,
    total_cost: f64,
    upstream_id: ?[]const u8,
    upstream_inference_cost: ?f64,
    usage: f64,
    user_agent: ?[]const u8,
    web_search_engine: ?[]const u8,
};

pub const ProviderResponse = struct {
    // Failed or partially reported provider attempts may omit these fields.
    endpoint_id: ?[]const u8 = null,
    id: ?[]const u8 = null,
    is_byok: ?bool = null,
    latency: ?f64 = null,
    model_permaslug: ?[]const u8 = null,
    provider_name: ?[]const u8 = null,
    status: ?f64 = null,
};

pub const GenerationContent = struct {
    input: ContentInput,
    output: ContentOutput,
};

pub const ContentInput = struct {
    prompt: ?[]const u8 = null,
    messages: ?[]std.json.Value = null,
};

pub const ContentOutput = struct {
    completion: ?[]const u8,
    reasoning: ?[]const u8,
};

const WireGetResponse = struct {
    data: Generation,
};

const WireContentResponse = struct {
    data: GenerationContent,
};

const WireFeedbackResponse = struct {
    data: FeedbackData,
};

pub fn get(client: anytype, request: GetRequest, request_options: options_mod.RequestOptions) !GetResponse {
    return getWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, request, request_options);
}

pub fn getWithTransport(
    allocator: std.mem.Allocator,
    config: config_mod.Config,
    transport: anytype,
    request: GetRequest,
    request_options: options_mod.RequestOptions,
) !GetResponse {
    const query = try queryString(allocator, request);
    defer allocator.free(query);

    var prepared = try http.prepareRequest(allocator, config, .{
        .method = .GET,
        .path = "/generation",
        .query = query,
    }, request_options);
    defer prepared.deinit();

    var response = try transport.execute(allocator, prepared);
    defer response.deinit();

    return parseGetResponse(allocator, response);
}

pub fn content(client: anytype, request: ContentRequest, request_options: options_mod.RequestOptions) !ContentResponse {
    return contentWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, request, request_options);
}

pub fn feedback(client: anytype, request: FeedbackRequest, request_options: options_mod.RequestOptions) !FeedbackResponse {
    return feedbackWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, request, request_options);
}

pub fn feedbackWithTransport(
    allocator: std.mem.Allocator,
    config: config_mod.Config,
    transport: anytype,
    request: FeedbackRequest,
    request_options: options_mod.RequestOptions,
) !FeedbackResponse {
    const body = try json.stringifyRequest(allocator, request);
    defer allocator.free(body);

    var prepared = try http.prepareRequest(allocator, config, .{
        .method = .POST,
        .path = "/generation/feedback",
        .body = body,
    }, request_options);
    defer prepared.deinit();

    var response = try transport.execute(allocator, prepared);
    defer response.deinit();
    return parseFeedbackResponse(allocator, response);
}

pub fn contentWithTransport(
    allocator: std.mem.Allocator,
    config: config_mod.Config,
    transport: anytype,
    request: ContentRequest,
    request_options: options_mod.RequestOptions,
) !ContentResponse {
    const query = try queryString(allocator, .{ .id = request.id });
    defer allocator.free(query);

    var prepared = try http.prepareRequest(allocator, config, .{
        .method = .GET,
        .path = "/generation/content",
        .query = query,
    }, request_options);
    defer prepared.deinit();

    var response = try transport.execute(allocator, prepared);
    defer response.deinit();

    return parseContentResponse(allocator, response);
}

pub fn parseGetResponse(allocator: std.mem.Allocator, response: http.HttpResponse) !GetResponse {
    if (errors.isErrorStatus(@backingInt(response.status))) return error.ApiError;

    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const arena_allocator = arena.allocator();

    const owned_body = try arena_allocator.dupe(u8, response.body);
    const parsed = try json.parseResponseLeaky(WireGetResponse, arena_allocator, owned_body);
    return .{
        .arena = arena,
        .data = parsed.data,
    };
}

pub fn parseContentResponse(allocator: std.mem.Allocator, response: http.HttpResponse) !ContentResponse {
    if (errors.isErrorStatus(@backingInt(response.status))) return error.ApiError;

    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const arena_allocator = arena.allocator();

    const owned_body = try arena_allocator.dupe(u8, response.body);
    const parsed = try json.parseResponseLeaky(WireContentResponse, arena_allocator, owned_body);
    return .{
        .arena = arena,
        .data = parsed.data,
    };
}

pub fn parseFeedbackResponse(allocator: std.mem.Allocator, response: http.HttpResponse) !FeedbackResponse {
    if (response.status != .ok) return error.ApiError;

    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const arena_allocator = arena.allocator();
    const owned_body = try arena_allocator.dupe(u8, response.body);
    const parsed = try json.parseResponseLeaky(WireFeedbackResponse, arena_allocator, owned_body);
    if (!parsed.data.success) return error.InvalidResponse;

    return .{
        .arena = arena,
        .data = parsed.data,
        .response_metadata = try http.ResponseMetadata.fromHttpResponse(arena_allocator, response),
    };
}

pub fn queryString(allocator: std.mem.Allocator, request: GetRequest) ![]u8 {
    return query_mod.single(allocator, "id", request.id);
}

test "generation get parses response and ignores unknown fields" {
    const body =
        \\{
        \\  "data": {
        \\    "api_type": "completions",
        \\    "app_id": null,
        \\    "cache_discount": null,
        \\    "cancelled": false,
        \\    "created_at": "2024-07-15T23:33:19.433273+00:00",
        \\    "external_user": null,
        \\    "finish_reason": "stop",
        \\    "generation_time": 1200,
        \\    "http_referer": "https://example.com",
        \\    "id": "gen-123",
        \\    "is_byok": false,
        \\    "latency": 1250,
        \\    "model": "openai/gpt-4o-mini",
        \\    "moderation_latency": null,
        \\    "native_finish_reason": "stop",
        \\    "native_tokens_cached": 3,
        \\    "native_tokens_completion": 25,
        \\    "native_tokens_completion_images": 0,
        \\    "native_tokens_prompt": 10,
        \\    "native_tokens_reasoning": 5,
        \\    "num_fetches": 0,
        \\    "num_input_audio_prompt": 0,
        \\    "num_media_completion": 0,
        \\    "num_media_prompt": 1,
        \\    "num_search_results": 5,
        \\    "origin": "https://openrouter.ai/",
        \\    "preset_id": null,
        \\    "provider_name": "OpenAI",
        \\    "provider_responses": [
        \\      {"endpoint_id": "endpoint-1", "id": "upstream-1", "is_byok": false, "latency": 100, "model_permaslug": "openai/gpt-4o-mini", "provider_name": "OpenAI", "status": 200}
        \\    ],
        \\    "request_id": "req-123",
        \\    "response_cache_source_id": null,
        \\    "router": "openrouter/auto",
        \\    "service_tier": "priority",
        \\    "session_id": null,
        \\    "streamed": true,
        \\    "tokens_completion": 25,
        \\    "tokens_prompt": 10,
        \\    "total_cost": 0.0015,
        \\    "upstream_id": "chatcmpl-123",
        \\    "upstream_inference_cost": 0.0012,
        \\    "usage": 0.0015,
        \\    "user_agent": "zig-test",
        \\    "web_search_engine": null,
        \\    "unknown": true
        \\  }
        \\}
    ;

    var result = try getWithTransport(std.testing.allocator, config_mod.Config{ .api_key = "test-key" }, http.FakeTransport{ .body = body }, .{ .id = "gen-123" }, .{});
    defer result.deinit();

    try std.testing.expectEqualStrings("gen-123", result.data.id);
    try std.testing.expectEqualStrings("completions", result.data.api_type.?);
    try std.testing.expectEqualStrings("openai/gpt-4o-mini", result.data.model);
    try std.testing.expectEqual(@as(bool, false), result.data.is_byok);
    try std.testing.expectEqual(@as(?u64, 25), result.data.tokens_completion);
    try std.testing.expectEqual(@as(f64, 0.0015), result.data.total_cost);
    try std.testing.expectEqual(@as(usize, 1), result.data.provider_responses.?.len);
    try std.testing.expectEqual(@as(?f64, 200), result.data.provider_responses.?[0].status);
}

test "generation get sends GET /generation with escaped id" {
    const query = try queryString(std.testing.allocator, .{ .id = "gen 123/abc" });
    defer std.testing.allocator.free(query);

    var prepared = try http.prepareRequest(std.testing.allocator, .{ .api_key = "test-key" }, .{
        .method = .GET,
        .path = "/generation",
        .query = query,
    }, .{});
    defer prepared.deinit();

    try std.testing.expectEqual(std.http.Method.GET, prepared.method);
    try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/generation?id=gen%20123%2Fabc", prepared.url);
}

test "generation get maps error status to ApiError" {
    try std.testing.expectError(error.ApiError, getWithTransport(
        std.testing.allocator,
        config_mod.Config{ .api_key = "test-key" },
        http.FakeTransport{ .status = .not_found, .body = "{\"error\":{\"message\":\"not found\"}}" },
        .{ .id = "gen-missing" },
        .{},
    ));
}

test "generation content parses prompt response and ignores unknown fields" {
    const body =
        \\{
        \\  "data": {
        \\    "input": {
        \\      "prompt": "Say hello.",
        \\      "unknown": true
        \\    },
        \\    "output": {
        \\      "completion": "Hello!",
        \\      "reasoning": null,
        \\      "unknown": true
        \\    },
        \\    "unknown": true
        \\  }
        \\}
    ;

    var result = try contentWithTransport(std.testing.allocator, config_mod.Config{ .api_key = "test-key" }, http.FakeTransport{ .body = body }, .{ .id = "gen-123" }, .{});
    defer result.deinit();

    try std.testing.expectEqualStrings("Say hello.", result.data.input.prompt.?);
    try std.testing.expectEqual(null, result.data.input.messages);
    try std.testing.expectEqualStrings("Hello!", result.data.output.completion.?);
    try std.testing.expectEqual(null, result.data.output.reasoning);
}

test "generation content parses messages response" {
    const body =
        \\{
        \\  "data": {
        \\    "input": {
        \\      "messages": [
        \\        {"role": "user", "content": "Hi"}
        \\      ]
        \\    },
        \\    "output": {
        \\      "completion": null,
        \\      "reasoning": "Because."
        \\    }
        \\  }
        \\}
    ;

    var result = try contentWithTransport(std.testing.allocator, config_mod.Config{ .api_key = "test-key" }, http.FakeTransport{ .body = body }, .{ .id = "gen-123" }, .{});
    defer result.deinit();

    try std.testing.expectEqual(null, result.data.input.prompt);
    try std.testing.expectEqual(@as(usize, 1), result.data.input.messages.?.len);
    try std.testing.expectEqualStrings("Because.", result.data.output.reasoning.?);
}

test "generation content sends GET /generation/content with escaped id" {
    const query = try queryString(std.testing.allocator, .{ .id = "gen 123/abc" });
    defer std.testing.allocator.free(query);

    var prepared = try http.prepareRequest(std.testing.allocator, .{ .api_key = "test-key" }, .{
        .method = .GET,
        .path = "/generation/content",
        .query = query,
    }, .{});
    defer prepared.deinit();

    try std.testing.expectEqual(std.http.Method.GET, prepared.method);
    try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/generation/content?id=gen%20123%2Fabc", prepared.url);
}

test "generation content maps error status to ApiError" {
    try std.testing.expectError(error.ApiError, contentWithTransport(
        std.testing.allocator,
        config_mod.Config{ .api_key = "test-key" },
        http.FakeTransport{ .status = .not_found, .body = "{\"error\":{\"message\":\"not found\"}}" },
        .{ .id = "gen-missing" },
        .{},
    ));
}

test "generation feedback serializes every category and optional comments" {
    const categories = [_]FeedbackCategory{
        .latency,
        .incoherence,
        .incorrect_response,
        .formatting,
        .billing,
        .api_error,
        .other,
    };
    for (categories) |category| {
        const body = try json.stringifyRequest(std.testing.allocator, FeedbackRequest{
            .generation_id = "gen-123",
            .category = category,
        });
        defer std.testing.allocator.free(body);
        const parsed = try std.json.parseFromSliceLeaky(struct {
            generation_id: []const u8,
            category: []const u8,
            comment: ?[]const u8 = null,
        }, std.testing.allocator, body, .{});
        try std.testing.expectEqualStrings("gen-123", parsed.generation_id);
        try std.testing.expectEqualStrings(@tagName(category), parsed.category);
        try std.testing.expectEqual(@as(?[]const u8, null), parsed.comment);
    }

    const empty_comment = try json.stringifyRequest(std.testing.allocator, FeedbackRequest{
        .generation_id = "gen-123",
        .category = .other,
        .comment = "",
    });
    defer std.testing.allocator.free(empty_comment);
    const parsed_empty_comment = try std.json.parseFromSliceLeaky(struct {
        generation_id: []const u8,
        category: []const u8,
        comment: ?[]const u8,
    }, std.testing.allocator, empty_comment, .{});
    try std.testing.expectEqualStrings("", parsed_empty_comment.comment.?);

    const nonempty_comment = try json.stringifyRequest(std.testing.allocator, FeedbackRequest{
        .generation_id = "gen-123",
        .category = .other,
        .comment = "Incorrect total",
    });
    defer std.testing.allocator.free(nonempty_comment);
    const parsed_nonempty_comment = try std.json.parseFromSliceLeaky(struct {
        comment: []const u8,
    }, std.testing.allocator, nonempty_comment, .{ .ignore_unknown_fields = true });
    try std.testing.expectEqualStrings("Incorrect total", parsed_nonempty_comment.comment);
}

test "generation feedback parses success and rejects invalid responses" {
    var result = try feedbackWithTransport(
        std.testing.allocator,
        .{ .api_key = "test-key" },
        http.FakeTransport{
            .body =
            \\{
            \\  "data": { "success": true },
            \\  "unknown": true
            \\}
            ,
            .headers = &.{.{ .name = "X-Request-ID", .value = "req_feedback" }},
        },
        .{ .generation_id = "gen-123", .category = .latency },
        .{},
    );
    defer result.deinit();
    try std.testing.expect(result.data.success);
    try std.testing.expectEqualStrings("req_feedback", result.response_metadata.request_id.?);

    const invalid_bodies = [_][]const u8{
        "{\"data\":{\"success\":false}}",
    };
    for (invalid_bodies) |body| {
        var response = try feedbackFakeResponse(std.testing.allocator, .ok, body);
        defer response.deinit();
        try std.testing.expectError(error.InvalidResponse, parseFeedbackResponse(std.testing.allocator, response));
    }

    var missing_success = try feedbackFakeResponse(std.testing.allocator, .ok, "{\"data\":{}}");
    defer missing_success.deinit();
    try std.testing.expectError(error.MissingField, parseFeedbackResponse(std.testing.allocator, missing_success));

    var missing_data = try feedbackFakeResponse(std.testing.allocator, .ok, "{}");
    defer missing_data.deinit();
    try std.testing.expectError(error.MissingField, parseFeedbackResponse(std.testing.allocator, missing_data));

    for ([_][]const u8{ "{\"data\":{\"success\":null}}", "{\"data\":{\"success\":1}}" }) |body| {
        var scalar_success = try feedbackFakeResponse(std.testing.allocator, .ok, body);
        defer scalar_success.deinit();
        try std.testing.expectError(error.UnexpectedToken, parseFeedbackResponse(std.testing.allocator, scalar_success));
    }
}

test "generation feedback maps documented errors and does not retry" {
    const statuses = [_]std.http.Status{ .bad_request, .unauthorized, .forbidden, .not_found, .too_many_requests, .internal_server_error, .service_unavailable, .no_content };
    for (statuses) |status| {
        try std.testing.expectError(error.ApiError, feedbackWithTransport(
            std.testing.allocator,
            .{ .api_key = "test-key" },
            http.FakeTransport{ .status = status },
            .{ .generation_id = "gen-123", .category = .other },
            .{},
        ));
    }
}

test "generation feedback sends POST JSON headers and request options" {
    var state = FeedbackRecordingState{};
    var transport = FeedbackRecordingTransport{ .state = &state };
    var result = try feedbackWithTransport(
        std.testing.allocator,
        .{
            .api_key = "management-key",
            .http_referer = "https://example.test/app",
            .x_title = "Feedback test",
        },
        &transport,
        .{
            .generation_id = "gen-123",
            .category = .billing,
            .comment = "Incorrect total",
        },
        .{ .extra_headers = &.{.{ .name = "X-Test-Header", .value = "present" }} },
    );
    defer result.deinit();

    try std.testing.expect(result.data.success);
    try std.testing.expectEqual(@as(usize, 1), state.calls);
}

test "generation feedback rejects reserved authorization request options before execute" {
    var state = FeedbackRecordingState{};
    var transport = FeedbackRecordingTransport{ .state = &state };
    try std.testing.expectError(error.OptionsInvalid, feedbackWithTransport(
        std.testing.allocator,
        .{ .api_key = "management-key" },
        &transport,
        .{ .generation_id = "gen-123", .category = .other },
        .{ .extra_headers = &.{.{ .name = "Authorization", .value = "Bearer override" }} },
    ));
    try std.testing.expectEqual(@as(usize, 0), state.calls);
}

test "generation feedback does not retry a service unavailable response" {
    var state = FeedbackRecordingState{};
    var transport = FeedbackRecordingTransport{
        .state = &state,
        .status = .service_unavailable,
    };
    try std.testing.expectError(error.ApiError, feedbackWithTransport(
        std.testing.allocator,
        .{ .api_key = "management-key" },
        &transport,
        .{ .generation_id = "gen-123", .category = .other },
        .{},
    ));
    try std.testing.expectEqual(@as(usize, 1), state.calls);
}

const FeedbackRecordingState = struct {
    calls: usize = 0,
};

const FeedbackRecordingTransport = struct {
    state: *FeedbackRecordingState,
    status: std.http.Status = .ok,

    fn execute(self: *FeedbackRecordingTransport, allocator: std.mem.Allocator, prepared: http.PreparedRequest) !http.HttpResponse {
        self.state.calls += 1;
        try std.testing.expectEqual(std.http.Method.POST, prepared.method);
        try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/generation/feedback", prepared.url);
        try std.testing.expectEqualStrings("application/json", findFeedbackHeader(prepared.headers, "content-type").?);
        try std.testing.expectEqualStrings("Bearer management-key", findFeedbackHeader(prepared.headers, "authorization").?);

        const body = try std.json.parseFromSliceLeaky(struct {
            generation_id: []const u8,
            category: []const u8,
            comment: ?[]const u8 = null,
        }, allocator, prepared.body.?, .{});
        if (self.status == .ok) {
            try std.testing.expectEqualStrings("https://example.test/app", findFeedbackHeader(prepared.headers, "http-referer").?);
            try std.testing.expectEqualStrings("Feedback test", findFeedbackHeader(prepared.headers, "x-title").?);
            try std.testing.expectEqualStrings("present", findFeedbackHeader(prepared.headers, "x-test-header").?);
            try std.testing.expectEqualStrings("gen-123", body.generation_id);
            try std.testing.expectEqualStrings("billing", body.category);
            try std.testing.expectEqualStrings("Incorrect total", body.comment.?);
        }

        return (http.FakeTransport{ .status = self.status, .body = "{\"data\":{\"success\":true}}" }).execute(allocator, prepared);
    }
};

fn findFeedbackHeader(headers: []const options_mod.Header, name: []const u8) ?[]const u8 {
    for (headers) |header| {
        if (std.ascii.eqlIgnoreCase(header.name, name)) return header.value;
    }
    return null;
}

fn feedbackFakeResponse(allocator: std.mem.Allocator, status: std.http.Status, body: []const u8) !http.HttpResponse {
    var prepared = try http.prepareRequest(allocator, .{ .api_key = "test-key" }, .{
        .method = .POST,
        .path = "/generation/feedback",
    }, .{});
    defer prepared.deinit();
    return (http.FakeTransport{ .status = status, .body = body }).execute(allocator, prepared);
}

test "generation provider attempts accept omitted metadata" {
    var parsed = try json.parseResponse(
        []ProviderResponse,
        std.testing.allocator,
        "[{\"provider_name\":\"Provider\",\"status\":502},{\"status\":200,\"latency\":12,\"future\":true}]",
    );
    defer parsed.deinit();
    try std.testing.expectEqual(@as(usize, 2), parsed.value.len);
    try std.testing.expectEqual(@as(?f64, 502), parsed.value[0].status);
    try std.testing.expect(parsed.value[0].endpoint_id == null);
    try std.testing.expect(parsed.value[0].id == null);
    try std.testing.expect(parsed.value[0].is_byok == null);
    try std.testing.expect(parsed.value[0].latency == null);
    try std.testing.expect(parsed.value[0].model_permaslug == null);
    try std.testing.expectEqualStrings("Provider", parsed.value[0].provider_name.?);
    try std.testing.expect(parsed.value[1].provider_name == null);
    try std.testing.expectEqual(@as(?f64, 200), parsed.value[1].status);
    try std.testing.expectEqual(@as(?f64, 12), parsed.value[1].latency);
}
