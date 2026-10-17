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
    data_collection: ?ProviderDataCollection = null,
    zdr: ?bool = null,
    enforce_distillable_text: ?bool = null,
    /// Hard provider filter. Named `only_providers` to retain the existing `only()` helper.
    only_providers: ?[]const []const u8 = null,
    ignore: ?[]const []const u8 = null,
    quantizations: ?[]const ProviderQuantization = null,
    sort: ?ProviderSort = null,
    preferred_min_throughput: ?ProviderPreference = null,
    preferred_max_latency: ?ProviderPreference = null,
    max_price: ?ProviderMaxPrice = null,
    /// Provider-specific options object keyed by provider slug. Borrowed until request serialization completes.
    options: ?std.json.Value = null,

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

    pub fn jsonStringify(self: ProviderRouting, jws: anytype) !void {
        try jws.beginObject();
        inline for (.{
            .{ "order", self.order },                     .{ "allow_fallbacks", self.allow_fallbacks },                   .{ "require_parameters", self.require_parameters },
            .{ "data_collection", self.data_collection }, .{ "zdr", self.zdr },                                           .{ "enforce_distillable_text", self.enforce_distillable_text },
            .{ "only", self.only_providers },             .{ "ignore", self.ignore },                                     .{ "quantizations", self.quantizations },
            .{ "sort", self.sort },                       .{ "preferred_min_throughput", self.preferred_min_throughput }, .{ "preferred_max_latency", self.preferred_max_latency },
            .{ "max_price", self.max_price },
        }) |field| {
            if (field[1]) |value| {
                try jws.objectField(field[0]);
                try jws.write(value);
            }
        }
        if (self.options) |options| {
            if (options != .object) return error.WriteFailed;
            try jws.objectField("options");
            try jws.write(options);
        }
        try jws.endObject();
    }
};

pub const ProviderDataCollection = enum { allow, deny };
pub const ProviderQuantization = enum { int4, int8, fp4, mxfp4, nvfp4, fp6, fp8, mxfp8, fp16, bf16, fp32, unknown };
pub const ProviderSortBy = enum { price, throughput, latency, exacto };
pub const ProviderSortPartition = enum { model, none };
pub const ProviderSort = union(enum) {
    value: ProviderSortBy,
    config: Config,
    pub const Config = struct { by: ?ProviderSortBy = null, partition: ?ProviderSortPartition = null };
    pub fn jsonStringify(self: ProviderSort, jws: anytype) !void {
        switch (self) {
            .value => |value| try jws.write(value),
            .config => |config| try jws.write(config),
        }
    }
};
pub const ProviderPreference = union(enum) {
    value: f64,
    percentiles: Percentiles,
    pub const Percentiles = struct { p50: ?f64 = null, p75: ?f64 = null, p90: ?f64 = null, p99: ?f64 = null };
    pub fn jsonStringify(self: ProviderPreference, jws: anytype) !void {
        switch (self) {
            .value => |value| try jws.write(value),
            .percentiles => |value| try jws.write(value),
        }
    }
};
pub const ProviderPrice = union(enum) {
    number: f64,
    string: []const u8,
    pub fn jsonStringify(self: ProviderPrice, jws: anytype) !void {
        switch (self) {
            .number => |value| try jws.write(value),
            .string => |value| try jws.write(value),
        }
    }
};
pub const ProviderMaxPrice = struct { prompt: ?ProviderPrice = null, completion: ?ProviderPrice = null, request: ?ProviderPrice = null, image: ?ProviderPrice = null, audio: ?ProviderPrice = null };

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
    /// Typed array-valued content. `content` remains the compatible string form.
    content_parts: ?[]AssistantContentPart = null,
    tool_calls: ?[]ResponseToolCall = null,
    reasoning: ?[]const u8 = null,
    reasoning_details: ?[]ReasoningDetail = null,
    annotations: ?[]Annotation = null,
    refusal: ?[]const u8 = null,
    images: ?[]GeneratedImage = null,
    audio: ?std.json.Value = null,
    /// Original decoded message object, owned by the parent response arena.
    raw: std.json.Value = .null,
};

pub const ResponseToolCall = struct {
    id: ?[]const u8 = null,
    type: ?[]const u8 = null,
    function: Function = .{},
    index: ?u32 = null,

    pub const Function = struct { name: ?[]const u8 = null, arguments: ?[]const u8 = null };
};

/// A streaming tool call. Unlike full calls, OpenRouter guarantees `index`.
pub const ToolCallDelta = struct {
    index: u32,
    id: ?[]const u8 = null,
    type: ?[]const u8 = null,
    function: Function = .{},

    pub const Function = struct { name: ?[]const u8 = null, arguments: ?[]const u8 = null };
};

/// Parts and raw values are owned by the parent response or chunk arena.
pub const AssistantContentPart = union(enum) {
    text: []const u8,
    image_url: ImageUrl,
    refusal: []const u8,
    audio: std.json.Value,
    raw: std.json.Value,
};

pub const ImageUrl = struct { url: []const u8 };
pub const GeneratedImage = struct { type: ?[]const u8 = null, image_url: ImageUrl };

pub const ReasoningDetail = union(enum) {
    summary: struct { summary: ?[]const u8 = null, id: ?[]const u8 = null, format: ?[]const u8 = null, index: ?u32 = null },
    text: struct { text: ?[]const u8 = null, signature: ?[]const u8 = null, id: ?[]const u8 = null, format: ?[]const u8 = null, index: ?u32 = null },
    encrypted: struct { data: ?[]const u8 = null, id: ?[]const u8 = null, format: ?[]const u8 = null, index: ?u32 = null },
    server_tool_call: struct { tool_name: ?[]const u8 = null, arguments: ?[]const u8 = null, result: ?[]const u8 = null, tool_call_id: ?[]const u8 = null, id: ?[]const u8 = null, format: ?[]const u8 = null, index: ?u32 = null },
    raw: std.json.Value,
};

pub const Annotation = union(enum) {
    url_citation: struct { url: ?[]const u8 = null, title: ?[]const u8 = null, start_index: ?u32 = null, end_index: ?u32 = null, content: ?[]const u8 = null },
    web_search_citation: struct { url: ?[]const u8 = null, title: ?[]const u8 = null, cited_text: ?[]const u8 = null, encrypted_index: ?[]const u8 = null },
    raw: std.json.Value,
};

pub const Usage = struct {
    prompt_tokens: ?u32 = null,
    completion_tokens: ?u32 = null,
    total_tokens: ?u32 = null,
};

const WireCompletionResponse = struct { id: []const u8, model: []const u8, choices: []std.json.Value, usage: ?Usage = null };

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
    if (errors.isErrorStatus(@backingInt(response.status))) return error.ApiError;

    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const arena_allocator = arena.allocator();

    const owned_body = try arena_allocator.dupe(u8, response.body);
    const parsed = try json.parseResponseLeaky(WireCompletionResponse, arena_allocator, owned_body);
    const choices = try parseChoices(arena_allocator, parsed.choices);
    const response_metadata = try http.ResponseMetadata.fromHttpResponse(arena_allocator, response);
    return .{
        .arena = arena,
        .response_metadata = response_metadata,
        .id = parsed.id,
        .model = parsed.model,
        .choices = choices,
        .usage = parsed.usage,
    };
}

fn parseChoices(allocator: std.mem.Allocator, values: []std.json.Value) ![]Choice {
    const choices = try allocator.alloc(Choice, values.len);
    for (values, choices) |value, *choice| {
        const object = objectValue(value) orelse return error.UnexpectedToken;
        choice.* = .{
            .index = uintField(object, "index") orelse 0,
            .message = try parseAssistantMessage(allocator, object.get("message") orelse return error.UnexpectedToken),
            .finish_reason = stringField(object, "finish_reason"),
            .native_finish_reason = stringField(object, "native_finish_reason"),
        };
    }
    return choices;
}

pub fn parseAssistantMessage(allocator: std.mem.Allocator, value: std.json.Value) !AssistantMessage {
    const object = objectValue(value) orelse return error.UnexpectedToken;
    const role_name = stringField(object, "role") orelse return error.UnexpectedToken;
    const content_value = object.get("content");
    var message: AssistantMessage = .{ .role = std.meta.stringToEnum(Role, role_name) orelse return error.InvalidEnumTag, .raw = value };
    if (content_value) |content| switch (content) {
        .string => |text| message.content = text,
        .array => |parts| message.content_parts = try parseAssistantContentParts(allocator, parts.items),
        .null => {},
        else => return error.UnexpectedToken,
    };
    message.tool_calls = try parseResponseToolCalls(allocator, object.get("tool_calls"));
    message.reasoning = stringField(object, "reasoning");
    message.reasoning_details = try parseReasoningDetails(allocator, object.get("reasoning_details"));
    message.annotations = try parseAnnotations(allocator, object.get("annotations"));
    message.refusal = stringField(object, "refusal");
    message.images = try parseImages(allocator, object.get("images"));
    message.audio = object.get("audio");
    return message;
}

pub fn parseToolCallDeltas(allocator: std.mem.Allocator, value: ?std.json.Value) !?[]ToolCallDelta {
    const array = try optionalArray(value) orelse return null;
    const result = try allocator.alloc(ToolCallDelta, array.items.len);
    for (array.items, result) |item, *call| {
        const object = objectValue(item) orelse return error.UnexpectedToken;
        const function = objectValue(object.get("function") orelse .null) orelse std.json.ObjectMap.empty;
        call.* = .{ .index = uintField(object, "index") orelse return error.UnexpectedToken, .id = stringField(object, "id"), .type = stringField(object, "type"), .function = .{ .name = stringField(function, "name"), .arguments = stringField(function, "arguments") } };
    }
    return result;
}

fn parseResponseToolCalls(allocator: std.mem.Allocator, value: ?std.json.Value) !?[]ResponseToolCall {
    const array = try optionalArray(value) orelse return null;
    const result = try allocator.alloc(ResponseToolCall, array.items.len);
    for (array.items, result) |item, *call| {
        const object = objectValue(item) orelse return error.UnexpectedToken;
        const function = objectValue(object.get("function") orelse .null) orelse std.json.ObjectMap.empty;
        call.* = .{ .id = stringField(object, "id"), .type = stringField(object, "type"), .index = uintField(object, "index"), .function = .{ .name = stringField(function, "name"), .arguments = stringField(function, "arguments") } };
    }
    return result;
}

pub fn parseAssistantContentParts(allocator: std.mem.Allocator, values: []std.json.Value) ![]AssistantContentPart {
    const result = try allocator.alloc(AssistantContentPart, values.len);
    for (values, result) |value, *part| {
        const object = objectValue(value) orelse {
            part.* = .{ .raw = value };
            continue;
        };
        const kind = stringField(object, "type") orelse {
            part.* = .{ .raw = value };
            continue;
        };
        if (std.mem.eql(u8, kind, "text")) if (stringField(object, "text")) |text| {
            part.* = .{ .text = text };
            continue;
        };
        if (std.mem.eql(u8, kind, "image_url")) if (objectValue(object.get("image_url") orelse .null)) |image| if (stringField(image, "url")) |url| {
            part.* = .{ .image_url = .{ .url = url } };
            continue;
        };
        if (std.mem.eql(u8, kind, "refusal")) if (stringField(object, "refusal")) |text| {
            part.* = .{ .refusal = text };
            continue;
        };
        if (std.mem.eql(u8, kind, "audio")) {
            part.* = .{ .audio = value };
            continue;
        }
        part.* = .{ .raw = value };
    }
    return result;
}

pub fn parseReasoningDetails(allocator: std.mem.Allocator, value: ?std.json.Value) !?[]ReasoningDetail {
    const array = try optionalArray(value) orelse return null;
    const result = try allocator.alloc(ReasoningDetail, array.items.len);
    for (array.items, result) |item, *detail| {
        const o = objectValue(item) orelse {
            detail.* = .{ .raw = item };
            continue;
        };
        const common = CommonDetail{ .id = stringField(o, "id"), .format = stringField(o, "format"), .index = uintField(o, "index") };
        const kind = stringField(o, "type") orelse {
            detail.* = .{ .raw = item };
            continue;
        };
        if (std.mem.eql(u8, kind, "reasoning.summary")) {
            detail.* = .{ .summary = .{ .summary = stringField(o, "summary"), .id = common.id, .format = common.format, .index = common.index } };
        } else if (std.mem.eql(u8, kind, "reasoning.text")) {
            detail.* = .{ .text = .{ .text = stringField(o, "text"), .signature = stringField(o, "signature"), .id = common.id, .format = common.format, .index = common.index } };
        } else if (std.mem.eql(u8, kind, "reasoning.encrypted")) {
            detail.* = .{ .encrypted = .{ .data = stringField(o, "data"), .id = common.id, .format = common.format, .index = common.index } };
        } else if (std.mem.eql(u8, kind, "reasoning.server_tool_call")) {
            detail.* = .{ .server_tool_call = .{ .tool_name = stringField(o, "tool_name"), .arguments = stringField(o, "arguments"), .result = stringField(o, "result"), .tool_call_id = stringField(o, "tool_call_id"), .id = common.id, .format = common.format, .index = common.index } };
        } else {
            detail.* = .{ .raw = item };
        }
    }
    return result;
}
const CommonDetail = struct { id: ?[]const u8, format: ?[]const u8, index: ?u32 };
pub fn parseAnnotations(allocator: std.mem.Allocator, value: ?std.json.Value) !?[]Annotation {
    const array = try optionalArray(value) orelse return null;
    const result = try allocator.alloc(Annotation, array.items.len);
    for (array.items, result) |item, *annotation| {
        const o = objectValue(item) orelse {
            annotation.* = .{ .raw = item };
            continue;
        };
        const kind = stringField(o, "type") orelse {
            annotation.* = .{ .raw = item };
            continue;
        };
        if (std.mem.eql(u8, kind, "url_citation")) {
            const citation = objectValue(o.get("url_citation") orelse .null) orelse {
                annotation.* = .{ .raw = item };
                continue;
            };
            annotation.* = .{ .url_citation = .{ .url = stringField(citation, "url"), .title = stringField(citation, "title"), .start_index = uintField(citation, "start_index"), .end_index = uintField(citation, "end_index"), .content = stringField(citation, "content") } };
        } else if (std.mem.eql(u8, kind, "web_search_citation")) {
            const citation = objectValue(o.get("web_search_citation") orelse .null) orelse {
                annotation.* = .{ .raw = item };
                continue;
            };
            annotation.* = .{ .web_search_citation = .{ .url = stringField(citation, "url"), .title = stringField(citation, "title"), .cited_text = stringField(citation, "cited_text"), .encrypted_index = stringField(citation, "encrypted_index") } };
        } else annotation.* = .{ .raw = item };
    }
    return result;
}
pub fn parseImages(allocator: std.mem.Allocator, value: ?std.json.Value) !?[]GeneratedImage {
    const array = try optionalArray(value) orelse return null;
    const result = try allocator.alloc(GeneratedImage, array.items.len);
    for (array.items, result) |item, *image| {
        const o = objectValue(item) orelse return error.UnexpectedToken;
        const image_url = objectValue(o.get("image_url") orelse return error.UnexpectedToken) orelse return error.UnexpectedToken;
        image.* = .{ .type = stringField(o, "type"), .image_url = .{ .url = stringField(image_url, "url") orelse return error.UnexpectedToken } };
    }
    return result;
}
fn objectValue(value: std.json.Value) ?std.json.ObjectMap {
    return if (value == .object) value.object else null;
}
fn arrayValue(value: std.json.Value) ?std.json.Array {
    return if (value == .array) value.array else null;
}
fn optionalArray(value: ?std.json.Value) !?std.json.Array {
    const present = value orelse return null;
    if (present == .null) return null;
    return arrayValue(present) orelse error.UnexpectedToken;
}
fn stringField(object: std.json.ObjectMap, key: []const u8) ?[]const u8 {
    const value = object.get(key) orelse return null;
    return if (value == .string) value.string else null;
}
fn uintField(object: std.json.ObjectMap, key: []const u8) ?u32 {
    const value = object.get(key) orelse return null;
    return if (value == .integer and value.integer >= 0 and value.integer <= std.math.maxInt(u32)) @intCast(value.integer) else null;
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

test "chat request serializes typed provider routing" {
    const messages = &.{Message{ .role = .user, .content = .{ .text = "Hello" } }};
    const quantizations = &.{ .int4, .int8, .fp4, .mxfp4, .nvfp4, .fp6, .fp8, .mxfp8, .fp16, .bf16, .fp32, .unknown };
    var provider_options: std.json.ObjectMap = .empty;
    defer provider_options.deinit(std.testing.allocator);
    try provider_options.put(std.testing.allocator, "openai", .{ .object = .empty });
    const body = try json.stringifyRequest(std.testing.allocator, CompletionRequest{
        .model = "m",
        .messages = messages,
        .provider = .{
            .data_collection = .deny,
            .zdr = false,
            .enforce_distillable_text = true,
            .only_providers = &.{ "openai", "azure" },
            .ignore = &.{"slow"},
            .quantizations = quantizations,
            .sort = .{ .config = .{ .by = .exacto, .partition = .none } },
            .preferred_min_throughput = .{ .value = 1.5 },
            .preferred_max_latency = .{ .percentiles = .{ .p75 = 2, .p90 = 3, .p99 = 4 } },
            .max_price = .{ .prompt = .{ .number = 1.5 }, .completion = .{ .string = "2" }, .request = .{ .number = 3 }, .image = .{ .string = "4" }, .audio = .{ .number = 5 } },
            .options = .{ .object = provider_options },
        },
    });
    defer std.testing.allocator.free(body);
    var parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, body, .{});
    defer parsed.deinit();
    const provider = parsed.value.object.get("provider").?.object;
    try std.testing.expectEqualStrings("deny", provider.get("data_collection").?.string);
    try std.testing.expectEqual(false, provider.get("zdr").?.bool);
    try std.testing.expectEqual(@as(usize, 2), provider.get("only").?.array.items.len);
    try std.testing.expectEqualStrings("slow", provider.get("ignore").?.array.items[0].string);
    const expected_quantizations = [_][]const u8{ "int4", "int8", "fp4", "mxfp4", "nvfp4", "fp6", "fp8", "mxfp8", "fp16", "bf16", "fp32", "unknown" };
    for (provider.get("quantizations").?.array.items, expected_quantizations) |value, expected| try std.testing.expectEqualStrings(expected, value.string);
    try std.testing.expectEqualStrings("exacto", provider.get("sort").?.object.get("by").?.string);
    try std.testing.expectEqualStrings("none", provider.get("sort").?.object.get("partition").?.string);
    try std.testing.expectEqual(@as(f64, 1.5), provider.get("preferred_min_throughput").?.float);
    const latency = provider.get("preferred_max_latency").?.object;
    try std.testing.expect(latency.get("p50") == null);
    try std.testing.expectEqual(@as(i64, 2), latency.get("p75").?.integer);
    try std.testing.expectEqual(@as(i64, 3), latency.get("p90").?.integer);
    try std.testing.expectEqual(@as(i64, 4), latency.get("p99").?.integer);
    try std.testing.expectEqualStrings("2", provider.get("max_price").?.object.get("completion").?.string);
    try std.testing.expectEqual(@as(f64, 1.5), provider.get("max_price").?.object.get("prompt").?.float);
    try std.testing.expect(provider.get("options").?.object.get("openai") != null);
    try std.testing.expect(parsed.value.object.get("openai") == null);
}

test "provider routing omits nulls and confines raw options" {
    const messages = &.{Message{ .role = .user, .content = .{ .text = "Hello" } }};
    const without_provider = try json.stringifyRequest(std.testing.allocator, CompletionRequest{ .model = "m", .messages = messages });
    defer std.testing.allocator.free(without_provider);
    var parsed_without = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, without_provider, .{});
    defer parsed_without.deinit();
    try std.testing.expect(parsed_without.value.object.get("provider") == null);

    const empty = try json.stringifyRequest(std.testing.allocator, CompletionRequest{ .model = "m", .messages = messages, .provider = .{} });
    defer std.testing.allocator.free(empty);
    var parsed_empty = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, empty, .{});
    defer parsed_empty.deinit();
    try std.testing.expectEqual(@as(usize, 0), parsed_empty.value.object.get("provider").?.object.count());

    try std.testing.expectError(error.WriteFailed, json.stringifyRequest(std.testing.allocator, CompletionRequest{ .model = "m", .messages = messages, .provider = .{ .options = .{ .string = "not-an-object" } } }));

    const scalar = try json.stringifyRequest(std.testing.allocator, CompletionRequest{ .model = "m", .messages = messages, .provider = .{ .data_collection = .allow, .zdr = true, .enforce_distillable_text = false, .sort = .{ .value = .price } } });
    defer std.testing.allocator.free(scalar);
    var parsed_scalar = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, scalar, .{});
    defer parsed_scalar.deinit();
    const provider = parsed_scalar.value.object.get("provider").?.object;
    try std.testing.expectEqualStrings("allow", provider.get("data_collection").?.string);
    try std.testing.expectEqual(true, provider.get("zdr").?.bool);
    try std.testing.expectEqual(false, provider.get("enforce_distillable_text").?.bool);
    try std.testing.expectEqualStrings("price", provider.get("sort").?.string);
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

test "chat completion parses rich assistant response fields" {
    const body = try std.testing.allocator.dupe(u8,
        \\{"id":"gen","model":"m","choices":[{"message":{"role":"assistant","content":[{"type":"text","text":"hello"},{"type":"image_url","image_url":{"url":"https://example.com/a.png"}},{"type":"audio","data":"a"},{"type":"future","x":1}],"tool_calls":[{"id":"call","type":"function","function":{"name":"weather","arguments":"{}"}}],"reasoning":"think","reasoning_details":[{"type":"reasoning.summary","summary":"sum"},{"type":"reasoning.text","text":null,"signature":"sig"},{"type":"reasoning.encrypted","data":"enc"},{"type":"reasoning.server_tool_call","tool_name":"search","arguments":"{}","result":"ok","tool_call_id":"server"},{"type":"future"}],"annotations":[{"type":"url_citation","url_citation":{"url":"https://example.com","title":"Example","start_index":0,"end_index":1,"content":"quote"}},{"type":"web_search_citation","web_search_citation":{"url":"https://search.example","title":null,"cited_text":"cited","encrypted_index":"enc"}},{"type":"future"}],"refusal":"no","images":[{"type":"image_url","image_url":{"url":"https://example.com/out.png"}}],"audio":{"id":"audio"}}}]}
    );
    var result = try parseCompletionResponse(std.testing.allocator, .{ .allocator = std.testing.allocator, .status = .ok, .body = body });
    std.testing.allocator.free(body);
    defer result.deinit();

    const message = result.choices[0].message;
    try std.testing.expect(message.content == null);
    try std.testing.expectEqual(@as(usize, 4), message.content_parts.?.len);
    try std.testing.expect(message.content_parts.?[2] == .audio);
    try std.testing.expect(message.content_parts.?[3] == .raw);
    try std.testing.expectEqualStrings("weather", message.tool_calls.?[0].function.name.?);
    try std.testing.expect(message.reasoning_details.?[0] == .summary);
    try std.testing.expect(message.reasoning_details.?[1] == .text);
    try std.testing.expect(message.reasoning_details.?[2] == .encrypted);
    try std.testing.expect(message.reasoning_details.?[3] == .server_tool_call);
    try std.testing.expect(message.reasoning_details.?[4] == .raw);
    try std.testing.expectEqualStrings("https://example.com", message.annotations.?[0].url_citation.url.?);
    try std.testing.expectEqualStrings("quote", message.annotations.?[0].url_citation.content.?);
    try std.testing.expectEqualStrings("https://search.example", message.annotations.?[1].web_search_citation.url.?);
    try std.testing.expectEqualStrings("cited", message.annotations.?[1].web_search_citation.cited_text.?);
    try std.testing.expect(message.annotations.?[2] == .raw);
    try std.testing.expectEqualStrings("no", message.refusal.?);
    try std.testing.expectEqualStrings("https://example.com/out.png", message.images.?[0].image_url.url);
}

test "chat completion accepts null and omitted optional response fields" {
    const body = try std.testing.allocator.dupe(u8,
        \\{"id":"gen","model":"m","choices":[{"index":0,"message":{"role":"assistant","content":null,"tool_calls":null,"reasoning_details":null,"annotations":null,"images":null}},{"index":1,"message":{"role":"assistant"}}]}
    );
    var result = try parseCompletionResponse(std.testing.allocator, .{ .allocator = std.testing.allocator, .status = .ok, .body = body });
    std.testing.allocator.free(body);
    defer result.deinit();
    try std.testing.expect(result.choices[0].message.content == null);
    try std.testing.expect(result.choices[0].message.tool_calls == null);
    try std.testing.expect(result.choices[0].message.images == null);
    try std.testing.expect(result.choices[1].message.content == null);
}
