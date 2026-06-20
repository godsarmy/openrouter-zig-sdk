//! Chat completions API.

const std = @import("std");

const errors = @import("errors.zig");
const config_mod = @import("config.zig");
const http = @import("http.zig");
const json = @import("json.zig");
const options_mod = @import("options.zig");

pub const Role = enum {
    system,
    user,
    assistant,
    tool,
};

pub const Message = struct {
    role: Role,
    content: MessageContent,
    name: ?[]const u8 = null,
    tool_call_id: ?[]const u8 = null,
    tool_calls: ?[]const ToolCall = null,
};

pub const MessageContent = union(enum) {
    text: []const u8,
    parts: []const ContentPart,

    pub fn jsonStringify(self: MessageContent, jws: anytype) !void {
        switch (self) {
            .text => |text| try jws.write(text),
            .parts => |parts| try jws.write(parts),
        }
    }
};

pub const ContentPart = union(enum) {
    text: []const u8,
    image_url: []const u8,

    pub fn jsonStringify(self: ContentPart, jws: anytype) !void {
        try jws.beginObject();
        switch (self) {
            .text => |text| {
                try jws.objectField("type");
                try jws.write("text");
                try jws.objectField("text");
                try jws.write(text);
            },
            .image_url => |url| {
                try jws.objectField("type");
                try jws.write("image_url");
                try jws.objectField("image_url");
                try jws.beginObject();
                try jws.objectField("url");
                try jws.write(url);
                try jws.endObject();
            },
        }
        try jws.endObject();
    }
};

pub const ToolCall = struct {
    id: []const u8,
    name: []const u8,
    arguments: []const u8,
};

pub const CompletionRequest = struct {
    model: []const u8,
    messages: []const Message,
    temperature: ?f32 = null,
    top_p: ?f32 = null,
    max_tokens: ?u32 = null,
    seed: ?i64 = null,
    frequency_penalty: ?f32 = null,
    presence_penalty: ?f32 = null,
    response_format: ?ResponseFormat = null,
    provider: ?ProviderRouting = null,
    plugins: ?[]const Plugin = null,
    tools: ?[]const ServerTool = null,
    tool_choice: ?ToolChoice = null,
    stream: bool = false,
    stop: ?[]const []const u8 = null,
    extra_body: ?std.json.Value = null,

    pub fn jsonStringify(self: CompletionRequest, jws: anytype) !void {
        try jws.beginObject();
        try jws.objectField("model");
        try jws.write(self.model);
        try jws.objectField("messages");
        try jws.write(self.messages);
        if (self.temperature) |value| {
            try jws.objectField("temperature");
            try jws.write(value);
        }
        if (self.top_p) |value| {
            try jws.objectField("top_p");
            try jws.write(value);
        }
        if (self.max_tokens) |value| {
            try jws.objectField("max_tokens");
            try jws.write(value);
        }
        if (self.seed) |value| {
            try jws.objectField("seed");
            try jws.write(value);
        }
        if (self.frequency_penalty) |value| {
            try jws.objectField("frequency_penalty");
            try jws.write(value);
        }
        if (self.presence_penalty) |value| {
            try jws.objectField("presence_penalty");
            try jws.write(value);
        }
        if (self.response_format) |value| {
            try jws.objectField("response_format");
            try jws.write(value);
        }
        if (self.provider) |value| {
            try jws.objectField("provider");
            try jws.write(value);
        }
        if (self.plugins) |value| {
            try jws.objectField("plugins");
            try jws.write(value);
        }
        if (self.tools) |value| {
            try jws.objectField("tools");
            try jws.write(value);
        }
        if (self.tool_choice) |value| {
            try jws.objectField("tool_choice");
            try jws.write(value);
        }
        try jws.objectField("stream");
        try jws.write(self.stream);
        if (self.stop) |value| {
            try jws.objectField("stop");
            try jws.write(value);
        }
        if (self.extra_body) |value| switch (value) {
            .object => |object| {
                var it = object.iterator();
                while (it.next()) |entry| {
                    try jws.objectField(entry.key_ptr.*);
                    try jws.write(entry.value_ptr.*);
                }
            },
            else => {},
        };
        try jws.endObject();
    }
};

pub const ResponseFormat = struct {
    type: ResponseFormatType,
};

pub const ResponseFormatType = union(enum) {
    text,
    json_object,
    json_schema,
    raw: []const u8,

    pub fn jsonStringify(self: ResponseFormatType, jws: anytype) !void {
        switch (self) {
            .text => try jws.write("text"),
            .json_object => try jws.write("json_object"),
            .json_schema => try jws.write("json_schema"),
            .raw => |value| try jws.write(value),
        }
    }
};

pub const ProviderRouting = struct {
    order: ?[]const []const u8 = null,
    allow_fallbacks: ?bool = null,
    require_parameters: ?bool = null,

    pub fn prefer(order: []const []const u8) ProviderRouting {
        return .{ .order = order };
    }

    pub fn only(order: []const []const u8) ProviderRouting {
        return .{ .order = order, .allow_fallbacks = false };
    }

    pub fn withRequiredParameters(self: ProviderRouting) ProviderRouting {
        var copy = self;
        copy.require_parameters = true;
        return copy;
    }
};

pub const Plugin = union(enum) {
    fusion: FusionPlugin,
    raw: std.json.Value,

    pub fn jsonStringify(self: Plugin, jws: anytype) !void {
        switch (self) {
            .fusion => |plugin| try jws.write(plugin),
            .raw => |value| try jws.write(value),
        }
    }
};

pub const FusionPlugin = struct {
    preset: ?[]const u8 = null,
    analysis_models: ?[]const []const u8 = null,
    model: ?[]const u8 = null,
    max_tool_calls: ?u8 = null,
    enabled: ?bool = null,

    pub fn jsonStringify(self: FusionPlugin, jws: anytype) !void {
        try jws.beginObject();
        try jws.objectField("id");
        try jws.write("fusion");
        if (self.preset) |value| {
            try jws.objectField("preset");
            try jws.write(value);
        }
        if (self.analysis_models) |value| {
            try jws.objectField("analysis_models");
            try jws.write(value);
        }
        if (self.model) |value| {
            try jws.objectField("model");
            try jws.write(value);
        }
        if (self.max_tool_calls) |value| {
            try jws.objectField("max_tool_calls");
            try jws.write(value);
        }
        if (self.enabled) |value| {
            try jws.objectField("enabled");
            try jws.write(value);
        }
        try jws.endObject();
    }
};

pub const ServerTool = union(enum) {
    fusion: FusionToolParameters,
    web_search: WebSearchToolParameters,
    web_fetch: WebFetchToolParameters,
    raw: std.json.Value,

    pub fn jsonStringify(self: ServerTool, jws: anytype) !void {
        switch (self) {
            .fusion => |parameters| try writeServerTool(jws, "openrouter:fusion", parameters),
            .web_search => |parameters| try writeServerTool(jws, "openrouter:web_search", parameters),
            .web_fetch => |parameters| try writeServerTool(jws, "openrouter:web_fetch", parameters),
            .raw => |value| try jws.write(value),
        }
    }
};

pub const ToolChoice = union(enum) {
    none,
    auto,
    required,
    raw: std.json.Value,

    pub fn jsonStringify(self: ToolChoice, jws: anytype) !void {
        switch (self) {
            .none => try jws.write("none"),
            .auto => try jws.write("auto"),
            .required => try jws.write("required"),
            .raw => |value| try jws.write(value),
        }
    }
};

pub const FusionToolParameters = struct {
    analysis_models: ?[]const []const u8 = null,
    model: ?[]const u8 = null,
    max_tool_calls: ?u8 = null,
    max_completion_tokens: ?u32 = null,
    reasoning: ?std.json.Value = null,
    temperature: ?f32 = null,

    fn isEmpty(self: FusionToolParameters) bool {
        return self.analysis_models == null and self.model == null and self.max_tool_calls == null and self.max_completion_tokens == null and self.reasoning == null and self.temperature == null;
    }

    pub fn jsonStringify(self: FusionToolParameters, jws: anytype) !void {
        try jws.beginObject();
        if (self.analysis_models) |value| {
            try jws.objectField("analysis_models");
            try jws.write(value);
        }
        if (self.model) |value| {
            try jws.objectField("model");
            try jws.write(value);
        }
        if (self.max_tool_calls) |value| {
            try jws.objectField("max_tool_calls");
            try jws.write(value);
        }
        if (self.max_completion_tokens) |value| {
            try jws.objectField("max_completion_tokens");
            try jws.write(value);
        }
        if (self.reasoning) |value| {
            try jws.objectField("reasoning");
            try jws.write(value);
        }
        if (self.temperature) |value| {
            try jws.objectField("temperature");
            try jws.write(value);
        }
        try jws.endObject();
    }
};

pub const WebSearchToolParameters = struct {
    engine: ?[]const u8 = null,
    max_results: ?u8 = null,
    max_total_results: ?u32 = null,
    search_context_size: ?WebSearchContextSize = null,
    max_characters: ?u32 = null,
    user_location: ?UserLocation = null,
    allowed_domains: ?[]const []const u8 = null,
    excluded_domains: ?[]const []const u8 = null,

    fn isEmpty(self: WebSearchToolParameters) bool {
        return self.engine == null and self.max_results == null and self.max_total_results == null and self.search_context_size == null and self.max_characters == null and self.user_location == null and self.allowed_domains == null and self.excluded_domains == null;
    }

    pub fn jsonStringify(self: WebSearchToolParameters, jws: anytype) !void {
        try jws.beginObject();
        if (self.engine) |value| {
            try jws.objectField("engine");
            try jws.write(value);
        }
        if (self.max_results) |value| {
            try jws.objectField("max_results");
            try jws.write(value);
        }
        if (self.max_total_results) |value| {
            try jws.objectField("max_total_results");
            try jws.write(value);
        }
        if (self.search_context_size) |value| {
            try jws.objectField("search_context_size");
            try jws.write(value);
        }
        if (self.max_characters) |value| {
            try jws.objectField("max_characters");
            try jws.write(value);
        }
        if (self.user_location) |value| {
            try jws.objectField("user_location");
            try jws.write(value);
        }
        if (self.allowed_domains) |value| {
            try jws.objectField("allowed_domains");
            try jws.write(value);
        }
        if (self.excluded_domains) |value| {
            try jws.objectField("excluded_domains");
            try jws.write(value);
        }
        try jws.endObject();
    }
};

pub const WebSearchContextSize = enum {
    low,
    medium,
    high,
};

pub const UserLocation = struct {
    type: UserLocationType = .approximate,
    city: ?[]const u8 = null,
    region: ?[]const u8 = null,
    country: ?[]const u8 = null,
    timezone: ?[]const u8 = null,
};

pub const UserLocationType = enum {
    approximate,
};

pub const WebFetchToolParameters = struct {
    engine: ?[]const u8 = null,
    max_uses: ?u32 = null,
    max_content_tokens: ?u32 = null,
    allowed_domains: ?[]const []const u8 = null,
    blocked_domains: ?[]const []const u8 = null,

    fn isEmpty(self: WebFetchToolParameters) bool {
        return self.engine == null and self.max_uses == null and self.max_content_tokens == null and self.allowed_domains == null and self.blocked_domains == null;
    }

    pub fn jsonStringify(self: WebFetchToolParameters, jws: anytype) !void {
        try jws.beginObject();
        if (self.engine) |value| {
            try jws.objectField("engine");
            try jws.write(value);
        }
        if (self.max_uses) |value| {
            try jws.objectField("max_uses");
            try jws.write(value);
        }
        if (self.max_content_tokens) |value| {
            try jws.objectField("max_content_tokens");
            try jws.write(value);
        }
        if (self.allowed_domains) |value| {
            try jws.objectField("allowed_domains");
            try jws.write(value);
        }
        if (self.blocked_domains) |value| {
            try jws.objectField("blocked_domains");
            try jws.write(value);
        }
        try jws.endObject();
    }
};

fn writeServerTool(jws: anytype, tool_type: []const u8, parameters: anytype) !void {
    try jws.beginObject();
    try jws.objectField("type");
    try jws.write(tool_type);
    if (!parameters.isEmpty()) {
        try jws.objectField("parameters");
        try jws.write(parameters);
    }
    try jws.endObject();
}

pub const CompletionResponse = struct {
    arena: std.heap.ArenaAllocator,
    response_metadata: http.ResponseMetadata = .{},
    id: []const u8,
    model: []const u8,
    choices: []Choice,
    usage: ?Usage = null,

    pub fn deinit(self: *CompletionResponse) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

pub const Choice = struct {
    index: u32 = 0,
    message: AssistantMessage,
    finish_reason: ?[]const u8 = null,
    native_finish_reason: ?[]const u8 = null,
};

pub const AssistantMessage = struct {
    role: Role,
    content: ?[]const u8 = null,
};

pub const Usage = struct {
    prompt_tokens: ?u32 = null,
    completion_tokens: ?u32 = null,
    total_tokens: ?u32 = null,
};

const WireCompletionResponse = struct {
    id: []const u8,
    model: []const u8,
    choices: []Choice,
    usage: ?Usage = null,
};

pub fn create(client: anytype, request: CompletionRequest, request_options: options_mod.RequestOptions) !CompletionResponse {
    return createWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, request, request_options);
}

pub fn createWithTransport(
    allocator: std.mem.Allocator,
    config: config_mod.Config,
    transport: anytype,
    request: CompletionRequest,
    request_options: options_mod.RequestOptions,
) !CompletionResponse {
    const body = try json.stringifyRequest(allocator, forceNonStreaming(request));
    defer allocator.free(body);

    var prepared = try http.prepareRequest(allocator, config, .{
        .method = .POST,
        .path = "/chat/completions",
        .body = body,
    }, request_options);
    defer prepared.deinit();

    var response = try transport.execute(allocator, prepared);
    defer response.deinit();

    return parseCompletionResponse(allocator, response);
}

pub fn parseCompletionResponse(allocator: std.mem.Allocator, response: http.HttpResponse) !CompletionResponse {
    if (errors.isErrorStatus(@intFromEnum(response.status))) return error.ApiError;

    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const arena_allocator = arena.allocator();

    const owned_body = try arena_allocator.dupe(u8, response.body);
    const parsed = try json.parseResponseLeaky(WireCompletionResponse, arena_allocator, owned_body);
    return .{
        .arena = arena,
        .response_metadata = try http.ResponseMetadata.fromHttpResponse(arena_allocator, response),
        .id = parsed.id,
        .model = parsed.model,
        .choices = parsed.choices,
        .usage = parsed.usage,
    };
}

fn forceNonStreaming(request: CompletionRequest) CompletionRequest {
    var copy = request;
    copy.stream = false;
    return copy;
}

test "chat request serializes content string and omits null optionals" {
    const messages = &.{Message{ .role = .user, .content = .{ .text = "Hello" } }};
    const body = try json.stringifyRequest(std.testing.allocator, forceNonStreaming(.{
        .model = "openai/gpt-4o-mini",
        .messages = messages,
    }));
    defer std.testing.allocator.free(body);

    try std.testing.expect(std.mem.indexOf(u8, body, "\"model\":\"openai/gpt-4o-mini\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"role\":\"user\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"content\":\"Hello\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"temperature\"") == null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"stream\":false") != null);
}

test "chat request serializes typed response format" {
    const messages = &.{Message{ .role = .user, .content = .{ .text = "Return JSON" } }};
    const body = try json.stringifyRequest(std.testing.allocator, CompletionRequest{
        .model = "openai/gpt-4o-mini",
        .messages = messages,
        .response_format = .{ .type = .json_object },
    });
    defer std.testing.allocator.free(body);

    try std.testing.expect(std.mem.indexOf(u8, body, "\"response_format\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"type\":\"json_object\"") != null);
}

test "chat request serializes provider routing helpers" {
    const messages = &.{Message{ .role = .user, .content = .{ .text = "Hello" } }};
    const body = try json.stringifyRequest(std.testing.allocator, CompletionRequest{
        .model = "openai/gpt-4o-mini",
        .messages = messages,
        .provider = ProviderRouting.only(&.{ "openai", "azure" }).withRequiredParameters(),
    });
    defer std.testing.allocator.free(body);

    try std.testing.expect(std.mem.indexOf(u8, body, "\"provider\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"order\":[\"openai\",\"azure\"]") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"allow_fallbacks\":false") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"require_parameters\":true") != null);
}

test "chat request merges extra body object fields" {
    var extra: std.json.ObjectMap = .empty;
    defer extra.deinit(std.testing.allocator);
    try extra.put(std.testing.allocator, "route", .{ .string = "fallback" });

    const messages = &.{Message{ .role = .user, .content = .{ .text = "Hello" } }};
    const body = try json.stringifyRequest(std.testing.allocator, CompletionRequest{
        .model = "openai/gpt-4o-mini",
        .messages = messages,
        .extra_body = .{ .object = extra },
    });
    defer std.testing.allocator.free(body);

    try std.testing.expect(std.mem.indexOf(u8, body, "\"route\":\"fallback\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"extra_body\"") == null);
}

test "chat request serializes fusion plugin" {
    const messages = &.{Message{ .role = .user, .content = .{ .text = "Compare options" } }};
    const analysis_models = &.{ "~anthropic/claude-opus-latest", "~openai/gpt-latest" };
    const plugins = &.{Plugin{ .fusion = .{
        .analysis_models = analysis_models,
        .model = "~openai/gpt-latest",
        .max_tool_calls = 4,
    } }};

    const body = try json.stringifyRequest(std.testing.allocator, CompletionRequest{
        .model = "openrouter/fusion",
        .messages = messages,
        .plugins = plugins,
    });
    defer std.testing.allocator.free(body);

    try std.testing.expect(std.mem.indexOf(u8, body, "\"plugins\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"id\":\"fusion\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"analysis_models\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "~anthropic/claude-opus-latest") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"model\":\"~openai/gpt-latest\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"max_tool_calls\":4") != null);
}

test "chat request serializes fusion preset plugin" {
    const messages = &.{Message{ .role = .user, .content = .{ .text = "Compare options" } }};
    const plugins = &.{Plugin{ .fusion = .{ .preset = "general-budget" } }};

    const body = try json.stringifyRequest(std.testing.allocator, CompletionRequest{
        .model = "openrouter/fusion",
        .messages = messages,
        .plugins = plugins,
    });
    defer std.testing.allocator.free(body);

    try std.testing.expect(std.mem.indexOf(u8, body, "\"id\":\"fusion\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"preset\":\"general-budget\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"analysis_models\"") == null);
}

test "chat request serializes openrouter fusion server tool" {
    const messages = &.{Message{ .role = .user, .content = .{ .text = "Compare options" } }};
    const analysis_models = &.{ "~google/gemini-flash-latest", "deepseek/deepseek-v3.2" };
    const tools = &.{ServerTool{ .fusion = .{
        .analysis_models = analysis_models,
        .model = "~anthropic/claude-opus-latest",
        .max_tool_calls = 4,
        .temperature = 0.2,
    } }};

    const body = try json.stringifyRequest(std.testing.allocator, CompletionRequest{
        .model = "openai/gpt-4o-mini",
        .messages = messages,
        .tools = tools,
        .tool_choice = .required,
    });
    defer std.testing.allocator.free(body);

    try std.testing.expect(std.mem.indexOf(u8, body, "\"tools\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"type\":\"openrouter:fusion\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"parameters\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"analysis_models\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"tool_choice\":\"required\"") != null);
}

test "chat request serializes web search and web fetch server tools" {
    const messages = &.{Message{ .role = .user, .content = .{ .text = "Find and fetch sources" } }};
    const allowed_domains = &.{"example.com"};
    const blocked_domains = &.{"private.example.com"};
    const tools = &.{
        ServerTool{ .web_search = .{
            .engine = "exa",
            .max_results = 3,
            .search_context_size = .medium,
            .allowed_domains = allowed_domains,
            .user_location = .{ .city = "San Francisco", .country = "US" },
        } },
        ServerTool{ .web_fetch = .{
            .engine = "openrouter",
            .max_uses = 2,
            .max_content_tokens = 50000,
            .blocked_domains = blocked_domains,
        } },
    };

    const body = try json.stringifyRequest(std.testing.allocator, CompletionRequest{
        .model = "openai/gpt-4o-mini",
        .messages = messages,
        .tools = tools,
    });
    defer std.testing.allocator.free(body);

    try std.testing.expect(std.mem.indexOf(u8, body, "\"type\":\"openrouter:web_search\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"engine\":\"exa\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"allowed_domains\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"user_location\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"type\":\"approximate\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"type\":\"openrouter:web_fetch\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"blocked_domains\"") != null);
}

test "chat request omits empty server tool parameters" {
    const messages = &.{Message{ .role = .user, .content = .{ .text = "Search if needed" } }};
    const tools = &.{ServerTool{ .web_search = .{} }};

    const body = try json.stringifyRequest(std.testing.allocator, CompletionRequest{
        .model = "openai/gpt-4o-mini",
        .messages = messages,
        .tools = tools,
    });
    defer std.testing.allocator.free(body);

    try std.testing.expect(std.mem.indexOf(u8, body, "\"type\":\"openrouter:web_search\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"parameters\"") == null);
}

test "chat request serializes multipart content" {
    const parts = &.{
        ContentPart{ .text = "Describe this" },
        ContentPart{ .image_url = "https://example.com/image.png" },
    };
    const messages = &.{Message{ .role = .user, .content = .{ .parts = parts } }};
    const body = try json.stringifyRequest(std.testing.allocator, CompletionRequest{
        .model = "openai/gpt-4o-mini",
        .messages = messages,
    });
    defer std.testing.allocator.free(body);

    try std.testing.expect(std.mem.indexOf(u8, body, "\"type\":\"text\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "\"type\":\"image_url\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, body, "https://example.com/image.png") != null);
}

test "chat create parses non-streaming completion" {
    const response_body =
        \\{
        \\  "id": "gen-123",
        \\  "object": "chat.completion",
        \\  "created": 123,
        \\  "model": "openai/gpt-4o-mini",
        \\  "choices": [
        \\    {
        \\      "index": 0,
        \\      "finish_reason": "stop",
        \\      "message": { "role": "assistant", "content": "Hi there" }
        \\    }
        \\  ],
        \\  "usage": { "prompt_tokens": 4, "completion_tokens": 2, "total_tokens": 6 }
        \\}
    ;
    const messages = &.{Message{ .role = .user, .content = .{ .text = "Hello" } }};

    var result = try createWithTransport(std.testing.allocator, .{ .api_key = "test-key" }, http.FakeTransport{
        .body = response_body,
        .headers = &.{
            .{ .name = "x-request-id", .value = "req_chat_123" },
            .{ .name = "x-ratelimit-remaining", .value = "42" },
            .{ .name = "x-ratelimit-reset", .value = "60" },
        },
    }, .{
        .model = "openai/gpt-4o-mini",
        .messages = messages,
    }, .{});
    defer result.deinit();

    try std.testing.expectEqualStrings("gen-123", result.id);
    try std.testing.expectEqualStrings("openai/gpt-4o-mini", result.model);
    try std.testing.expectEqual(@as(usize, 1), result.choices.len);
    try std.testing.expectEqual(Role.assistant, result.choices[0].message.role);
    try std.testing.expectEqualStrings("Hi there", result.choices[0].message.content.?);
    try std.testing.expectEqual(@as(?u32, 6), result.usage.?.total_tokens);
    try std.testing.expectEqualStrings("req_chat_123", result.response_metadata.request_id.?);
    try std.testing.expectEqualStrings("42", result.response_metadata.rate_limit_remaining.?);
    try std.testing.expectEqualStrings("60", result.response_metadata.rate_limit_reset.?);
}

test "chat create maps error status to ApiError" {
    const messages = &.{Message{ .role = .user, .content = .{ .text = "Hello" } }};

    try std.testing.expectError(error.ApiError, createWithTransport(
        std.testing.allocator,
        .{ .api_key = "test-key" },
        http.FakeTransport{ .status = .too_many_requests, .body = "{\"error\":{\"message\":\"rate limited\"}}" },
        .{ .model = "openai/gpt-4o-mini", .messages = messages },
        .{},
    ));
}
