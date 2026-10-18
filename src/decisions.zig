//! Typed questions for System One and the alpha Decisions API.
const std = @import("std");
const common = @import("enterprise.zig");
const config_mod = @import("config.zig");
const http = @import("http.zig");
const json = @import("json.zig");
const options_mod = @import("options.zig");

/// State and structured guidance remain JSON because their shape belongs to
/// the application. Question and answer discriminators are typed.
pub const Guidance = std.json.Value;
pub const Question = union(enum) {
    noul: struct { instructions: Guidance, criteria: ?struct { true: Guidance, false: Guidance } = null },
    choice: struct { instructions: Guidance, criteria: std.json.ArrayHashMap(Guidance) },
    score: struct { instructions: Guidance, criteria: []const Guidance },
    box: struct { instructions: Guidance },
    pub fn jsonStringify(self: @This(), writer: anytype) !void {
        try writer.beginObject();
        try writer.objectField("type");
        try writer.write(@tagName(self));
        switch (self) {
            inline else => |payload| {
                inline for (@typeInfo(@TypeOf(payload)).@"struct".field_names) |field_name| {
                    const value = @field(payload, field_name);
                    if (@typeInfo(@TypeOf(value)) != .optional or value != null) {
                        try writer.objectField(field_name);
                        try writer.write(value);
                    }
                }
            },
        }
        try writer.endObject();
    }
};
pub const Request = struct {
    model: []const u8,
    state: Guidance,
    questions: std.json.ArrayHashMap(Question),
    provider: ?@import("chat.zig").ProviderRouting = null,
    session_id: ?[]const u8 = null,
    trace: ?std.json.Value = null,
    user: ?[]const u8 = null,
};
pub const Box = struct { top: f64, bottom: f64, left: f64, right: f64 };
pub const Answer = union(enum) {
    noul: struct { noul: f64 },
    choice: struct { choice: []const u8, confidence: ?f64 = null, probabilities: ?std.json.ArrayHashMap(f64) = null },
    score: struct { score: f64, confidence: ?f64 = null, probabilities: ?std.json.ArrayHashMap(f64) = null, legend: ?std.json.ArrayHashMap(Guidance) = null },
    box: struct { box: Box, confidence: ?f64 = null },
    /// Forward compatibility for newly introduced answer kinds.
    unknown: std.json.Value,
    pub fn jsonParse(allocator: std.mem.Allocator, source: anytype, parse_options: std.json.ParseOptions) !@This() {
        const value = try std.json.Value.jsonParse(allocator, source, parse_options);
        return jsonParseFromValue(allocator, value, parse_options);
    }
    pub fn jsonParseFromValue(allocator: std.mem.Allocator, value: std.json.Value, parse_options: std.json.ParseOptions) !@This() {
        if (value != .object) return error.UnexpectedToken;
        const kind = value.object.get("type") orelse return error.MissingField;
        if (kind != .string) return error.UnexpectedToken;
        inline for (.{ "noul", "choice", "score", "box" }) |tag| {
            if (std.mem.eql(u8, kind.string, tag)) {
                const T = @FieldType(@This(), tag);
                var opts = parse_options;
                opts.ignore_unknown_fields = true;
                return @unionInit(@This(), tag, try std.json.parseFromValueLeaky(T, allocator, value, opts));
            }
        }
        return .{ .unknown = value };
    }
};
pub const Result = struct {
    id: ?[]const u8 = null,
    model: []const u8,
    provider: ?[]const u8 = null,
    answers: std.json.ArrayHashMap(Answer),
    usage: struct { input_tokens: u64, output_tokens: u64, cost: ?f64 = null },
};
pub const Response = common.Response(Result);
pub fn create(client: anytype, request: Request, request_options: options_mod.RequestOptions) !Response {
    return createWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, request, request_options);
}
pub fn createWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, request: Request, request_options: options_mod.RequestOptions) !Response {
    const body = try json.stringifyRequest(allocator, request);
    defer allocator.free(body);
    return common.execute(Result, allocator, config, transport, .{ .method = .POST, .path = "/systemone", .body = body }, request_options);
}
/// The alpha route is a sibling of /v1, as in OpenRouter's official AI SDK.
/// Custom API bases must end in /v1 so proxies retain their configured prefix.
pub fn alpha(client: anytype, request: Request, request_options: options_mod.RequestOptions) !Response {
    return alphaWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, request, request_options);
}
pub fn alphaWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, request: Request, request_options: options_mod.RequestOptions) !Response {
    const base = std.mem.trimEnd(u8, config.base_url, "/");
    if (!std.mem.endsWith(u8, base, "/v1")) return error.InvalidBaseUrl;
    var alpha_config = config;
    alpha_config.base_url = base[0 .. base.len - 3];
    const body = try json.stringifyRequest(allocator, request);
    defer allocator.free(body);
    return common.execute(Result, allocator, alpha_config, transport, .{ .method = .POST, .path = "/alpha/decisions", .body = body }, request_options);
}

test "System One serializes all question kinds and parses typed and future answers" {
    var questions: std.json.ArrayHashMap(Question) = .{};
    defer questions.deinit(std.testing.allocator);
    try questions.map.put(std.testing.allocator, "yes", .{ .noul = .{ .instructions = .{ .string = "Is this valid?" } } });
    var criteria: std.json.ArrayHashMap(Guidance) = .{};
    defer criteria.deinit(std.testing.allocator);
    try criteria.map.put(std.testing.allocator, "a", .{ .string = "A" });
    try questions.map.put(std.testing.allocator, "pick", .{ .choice = .{ .instructions = .{ .string = "Pick" }, .criteria = criteria } });
    try questions.map.put(std.testing.allocator, "rank", .{ .score = .{ .instructions = .{ .string = "Rank" }, .criteria = &.{ .{ .string = "low" }, .{ .string = "high" } } } });
    try questions.map.put(std.testing.allocator, "locate", .{ .box = .{ .instructions = .{ .string = "Locate" } } });
    const Transport = struct {
        pub fn execute(_: @This(), allocator: std.mem.Allocator, prepared: http.PreparedRequest) !http.HttpResponse {
            try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/systemone", prepared.url);
            var parsed = try json.parseResponse(std.json.Value, allocator, prepared.body.?);
            defer parsed.deinit();
            const qs = parsed.value.object.get("questions").?.object;
            try std.testing.expectEqualStrings("noul", qs.get("yes").?.object.get("type").?.string);
            try std.testing.expectEqualStrings("choice", qs.get("pick").?.object.get("type").?.string);
            try std.testing.expectEqualStrings("score", qs.get("rank").?.object.get("type").?.string);
            try std.testing.expectEqualStrings("box", qs.get("locate").?.object.get("type").?.string);
            return (http.FakeTransport{ .body = "{\"model\":\"typesafe/jev\",\"answers\":{\"yes\":{\"type\":\"noul\",\"noul\":0.9},\"pick\":{\"type\":\"choice\",\"choice\":\"a\",\"probabilities\":{\"a\":1}},\"rank\":{\"type\":\"score\",\"score\":1.5,\"legend\":{\"0\":\"low\"}},\"locate\":{\"type\":\"box\",\"box\":{\"top\":0,\"bottom\":1,\"left\":0,\"right\":1}},\"future\":{\"type\":\"new\",\"extra\":true}},\"usage\":{\"input_tokens\":10,\"output_tokens\":5}}" }).execute(allocator, prepared);
        }
    };
    var result = try createWithTransport(std.testing.allocator, .{ .api_key = "test" }, Transport{}, .{ .model = "jev", .state = .{ .string = "state" }, .questions = questions }, .{});
    defer result.deinit();
    try std.testing.expectEqual(@as(f64, 0.9), result.value.answers.map.get("yes").?.noul.noul);
    try std.testing.expectEqualStrings("a", result.value.answers.map.get("pick").?.choice.choice);
    try std.testing.expectEqual(@as(f64, 1.5), result.value.answers.map.get("rank").?.score.score);
    try std.testing.expect(result.value.answers.map.get("future").? == .unknown);
}

test "alpha Decisions uses sibling base and preserves proxy prefixes" {
    const Transport = struct {
        pub fn execute(_: @This(), allocator: std.mem.Allocator, prepared: http.PreparedRequest) !http.HttpResponse {
            try std.testing.expectEqualStrings("https://proxy.example.com/openrouter/api/alpha/decisions", prepared.url);
            return (http.FakeTransport{ .body = "{\"model\":\"m\",\"answers\":{},\"usage\":{\"input_tokens\":0,\"output_tokens\":0}}" }).execute(allocator, prepared);
        }
    };
    const request: Request = .{ .model = "m", .state = .{ .string = "s" }, .questions = .{} };
    var result = try alphaWithTransport(std.testing.allocator, .{ .api_key = "test", .base_url = "https://proxy.example.com/openrouter/api/v1/" }, Transport{}, request, .{});
    defer result.deinit();
    try std.testing.expectError(error.InvalidBaseUrl, alphaWithTransport(std.testing.allocator, .{ .api_key = "test", .base_url = "https://proxy.example.com/custom" }, http.FakeTransport{}, request, .{}));
    try std.testing.expectError(error.ApiError, createWithTransport(std.testing.allocator, .{ .api_key = "test" }, http.FakeTransport{ .status = .forbidden }, request, .{}));
}
