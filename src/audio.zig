//! Audio speech and transcription APIs.

const std = @import("std");

const config_mod = @import("config.zig");
const errors = @import("errors.zig");
const http = @import("http.zig");
const json = @import("json.zig");
const options_mod = @import("options.zig");

pub const SpeechCreateRequest = struct {
    model: []const u8,
    input: []const u8,
    voice: []const u8,
    response_format: ?SpeechFormat = null,
    speed: ?f64 = null,
    provider: ?std.json.Value = null,
};

pub const SpeechFormat = enum {
    mp3,
    pcm,
};

pub const SpeechCreateResponse = struct {
    response: http.HttpResponse,

    pub fn deinit(self: *SpeechCreateResponse) void {
        self.response.deinit();
        self.* = undefined;
    }

    pub fn data(self: SpeechCreateResponse) []const u8 {
        return self.response.body;
    }

    pub fn contentType(self: SpeechCreateResponse) ?[]const u8 {
        return self.response.content_type;
    }

    pub fn generationId(self: SpeechCreateResponse) ?[]const u8 {
        return self.response.generation_id;
    }
};

pub const TranscriptionsCreateRequest = struct {
    model: []const u8,
    input_audio: InputAudio,
    language: ?[]const u8 = null,
    temperature: ?f64 = null,
    provider: ?std.json.Value = null,
};

pub const InputAudio = struct {
    data: []const u8,
    format: []const u8,
};

pub const TranscriptionsCreateResponse = struct {
    arena: std.heap.ArenaAllocator,
    text: []const u8,
    usage: ?TranscriptionUsage = null,

    pub fn deinit(self: *TranscriptionsCreateResponse) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

pub const TranscriptionUsage = struct {
    cost: ?f64 = null,
    input_tokens: ?u32 = null,
    output_tokens: ?u32 = null,
    seconds: ?f64 = null,
    total_tokens: ?u32 = null,
};

const WireTranscriptionsCreateResponse = struct {
    text: []const u8,
    usage: ?TranscriptionUsage = null,
};

pub fn createSpeech(client: anytype, request: SpeechCreateRequest, request_options: options_mod.RequestOptions) !SpeechCreateResponse {
    return createSpeechWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, request, request_options);
}

pub fn createSpeechWithTransport(
    allocator: std.mem.Allocator,
    config: config_mod.Config,
    transport: anytype,
    request: SpeechCreateRequest,
    request_options: options_mod.RequestOptions,
) !SpeechCreateResponse {
    const body = try json.stringifyRequest(allocator, request);
    defer allocator.free(body);

    var prepared = try http.prepareRequest(allocator, config, .{
        .method = .POST,
        .path = "/audio/speech",
        .body = body,
        .accept = "audio/*",
    }, request_options);
    defer prepared.deinit();

    var response = try transport.execute(allocator, prepared);
    if (errors.isErrorStatus(@intFromEnum(response.status))) {
        response.deinit();
        return error.ApiError;
    }

    return .{ .response = response };
}

pub fn createTranscription(client: anytype, request: TranscriptionsCreateRequest, request_options: options_mod.RequestOptions) !TranscriptionsCreateResponse {
    return createTranscriptionWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, request, request_options);
}

pub fn createTranscriptionWithTransport(
    allocator: std.mem.Allocator,
    config: config_mod.Config,
    transport: anytype,
    request: TranscriptionsCreateRequest,
    request_options: options_mod.RequestOptions,
) !TranscriptionsCreateResponse {
    const body = try json.stringifyRequest(allocator, request);
    defer allocator.free(body);

    var prepared = try http.prepareRequest(allocator, config, .{
        .method = .POST,
        .path = "/audio/transcriptions",
        .body = body,
    }, request_options);
    defer prepared.deinit();

    var response = try transport.execute(allocator, prepared);
    defer response.deinit();

    return parseTranscriptionsCreateResponse(allocator, response);
}

pub fn parseTranscriptionsCreateResponse(allocator: std.mem.Allocator, response: http.HttpResponse) !TranscriptionsCreateResponse {
    if (errors.isErrorStatus(@intFromEnum(response.status))) return error.ApiError;

    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const arena_allocator = arena.allocator();

    const owned_body = try arena_allocator.dupe(u8, response.body);
    const parsed = try json.parseResponseLeaky(WireTranscriptionsCreateResponse, arena_allocator, owned_body);
    return .{
        .arena = arena,
        .text = parsed.text,
        .usage = parsed.usage,
    };
}

test "audio speech create serializes request" {
    const body = try json.stringifyRequest(std.testing.allocator, SpeechCreateRequest{
        .model = "elevenlabs/eleven-turbo-v2",
        .input = "Hello world",
        .voice = "alloy",
        .response_format = .pcm,
        .speed = 1,
    });
    defer std.testing.allocator.free(body);

    try std.testing.expect(std.mem.indexOf(u8, body, "\"model\":\"elevenlabs/eleven-turbo-v2\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"input\":\"Hello world\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"voice\":\"alloy\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"response_format\":\"pcm\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"speed\":1") != null);
}

test "audio speech create returns raw bytes" {
    const headers = &.{
        http.Header{ .name = "content-type", .value = "audio/pcm" },
        http.Header{ .name = "x-generation-id", .value = "gen_123" },
    };
    var result = try createSpeechWithTransport(std.testing.allocator, config_mod.Config{ .api_key = "test-key" }, http.FakeTransport{ .body = "audio-bytes", .headers = headers }, .{
        .model = "elevenlabs/eleven-turbo-v2",
        .input = "Hello world",
        .voice = "alloy",
    }, .{});
    defer result.deinit();

    try std.testing.expectEqualStrings("audio-bytes", result.data());
    try std.testing.expectEqualStrings("audio/pcm", result.contentType().?);
    try std.testing.expectEqualStrings("gen_123", result.generationId().?);
}

test "audio speech create sends POST /audio/speech" {
    const body = try json.stringifyRequest(std.testing.allocator, SpeechCreateRequest{
        .model = "elevenlabs/eleven-turbo-v2",
        .input = "Hello world",
        .voice = "alloy",
    });
    defer std.testing.allocator.free(body);

    var prepared = try http.prepareRequest(std.testing.allocator, .{ .api_key = "test-key" }, .{
        .method = .POST,
        .path = "/audio/speech",
        .body = body,
        .accept = "audio/*",
    }, .{});
    defer prepared.deinit();

    try std.testing.expectEqual(std.http.Method.POST, prepared.method);
    try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/audio/speech", prepared.url);
    try std.testing.expectEqualStrings(body, prepared.body.?);
}

test "audio speech create maps error status to ApiError" {
    try std.testing.expectError(error.ApiError, createSpeechWithTransport(
        std.testing.allocator,
        config_mod.Config{ .api_key = "test-key" },
        http.FakeTransport{ .status = .bad_request, .body = "{\"error\":{\"message\":\"bad request\"}}" },
        .{ .model = "elevenlabs/eleven-turbo-v2", .input = "Hello", .voice = "alloy" },
        .{},
    ));
}

test "audio transcriptions create serializes request" {
    const body = try json.stringifyRequest(std.testing.allocator, TranscriptionsCreateRequest{
        .model = "openai/whisper-large-v3",
        .input_audio = .{ .data = "UklGRiQA", .format = "wav" },
        .language = "en",
        .temperature = 0,
    });
    defer std.testing.allocator.free(body);

    try std.testing.expect(std.mem.indexOf(u8, body, "\"model\":\"openai/whisper-large-v3\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"input_audio\":{") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"data\":\"UklGRiQA\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"format\":\"wav\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"language\":\"en\"") != null);
}

test "audio transcriptions create parses response and ignores unknown fields" {
    const body =
        \\{
        \\  "text": "Hello world",
        \\  "usage": {
        \\    "cost": 0.01,
        \\    "input_tokens": 123,
        \\    "output_tokens": 0,
        \\    "seconds": 4.2,
        \\    "total_tokens": 123
        \\  },
        \\  "unknown": true
        \\}
    ;

    var result = try createTranscriptionWithTransport(std.testing.allocator, config_mod.Config{ .api_key = "test-key" }, http.FakeTransport{ .body = body }, .{
        .model = "openai/whisper-large-v3",
        .input_audio = .{ .data = "UklGRiQA", .format = "wav" },
    }, .{});
    defer result.deinit();

    try std.testing.expectEqualStrings("Hello world", result.text);
    try std.testing.expectApproxEqAbs(@as(f64, 0.01), result.usage.?.cost.?, 0.00001);
    try std.testing.expectEqual(@as(?u32, 123), result.usage.?.input_tokens);
    try std.testing.expectApproxEqAbs(@as(f64, 4.2), result.usage.?.seconds.?, 0.00001);
}

test "audio transcriptions create sends POST /audio/transcriptions" {
    const body = try json.stringifyRequest(std.testing.allocator, TranscriptionsCreateRequest{
        .model = "openai/whisper-large-v3",
        .input_audio = .{ .data = "UklGRiQA", .format = "wav" },
    });
    defer std.testing.allocator.free(body);

    var prepared = try http.prepareRequest(std.testing.allocator, .{ .api_key = "test-key" }, .{
        .method = .POST,
        .path = "/audio/transcriptions",
        .body = body,
    }, .{});
    defer prepared.deinit();

    try std.testing.expectEqual(std.http.Method.POST, prepared.method);
    try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/audio/transcriptions", prepared.url);
    try std.testing.expectEqualStrings(body, prepared.body.?);
}

test "audio transcriptions create maps error status to ApiError" {
    try std.testing.expectError(error.ApiError, createTranscriptionWithTransport(
        std.testing.allocator,
        config_mod.Config{ .api_key = "test-key" },
        http.FakeTransport{ .status = .bad_request, .body = "{\"error\":{\"message\":\"bad request\"}}" },
        .{ .model = "openai/whisper-large-v3", .input_audio = .{ .data = "UklGRiQA", .format = "wav" } },
        .{},
    ));
}
