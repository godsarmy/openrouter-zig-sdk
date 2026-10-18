//! Intern lifecycle. Global hosts only; access is workspace scoped. Daemon signing requires a personal OAuth bearer with vault:read, supplied as the client credential.
const std = @import("std");
const common = @import("enterprise.zig");
const config_mod = @import("config.zig");
const http = @import("http.zig");
const json = @import("json.zig");
const options_mod = @import("options.zig");
const query = @import("query.zig");
pub const Intern = struct {
    id: []const u8,
    name: []const u8,
    description: ?[]const u8,
    instructions: ?[]const u8,
    model: ?[]const u8,
    status: []const u8,
    last_failure_message: ?[]const u8,
    progress: ?struct { step_label: []const u8, step_number: u64, total_steps: u64 },
    hostname: ?[]const u8,
    workspace_id: []const u8,
    vault_id: ?[]const u8,
    attached_vault_id: ?[]const u8,
    created_at: []const u8,
    updated_at: []const u8,
};
pub const InternList = struct { data: []Intern, has_more: bool, next_cursor: ?[]const u8 = null };
/// Explicit workspace avoids ambiguity between the schema's optional workspace
/// and the endpoint documentation's explicit-workspace requirement.
pub const CreateRequest = struct {
    name: []const u8,
    workspace_id: []const u8,
    provision: ?bool = null,
    description: ?[]const u8 = null,
    instructions: ?[]const u8 = null,
    vault_id: ?[]const u8 = null,
};
pub const NullableString = common.Nullable([]const u8);
pub const UpdateRequest = struct {
    name: ?[]const u8 = null,
    description: ?NullableString = null,
    instructions: ?NullableString = null,
    model: ?NullableString = null,
};
pub const DeleteRequest = struct { acknowledge_workspace_loss: bool = false };
pub const ListRequest = struct { limit: ?u64 = null, status: ?[]const u8 = null, starting_after: ?[]const u8 = null, workspace_id: ?[]const u8 = null };
pub const DaemonAccess = struct { origin: []const u8, token: []const u8 };
pub const SignRequest = struct { bodySha256: []const u8 };
pub const Signature = struct { @"x-ori-invoke-signature": []const u8, @"x-ori-invoke-timestamp": []const u8, @"x-ori-invoke-user": []const u8 };
pub const InvokeRequest = struct { input: []const u8, session_id: ?[]const u8 = null };
pub const Accepted = struct { session_id: []const u8, status: []const u8 };
fn listQuery(allocator: std.mem.Allocator, request: ListRequest) ![]u8 {
    var limit: [20]u8 = undefined;
    return query.build(allocator, &.{
        .{ .name = "limit", .value = if (request.limit) |v| try std.fmt.bufPrint(&limit, "{d}", .{v}) else null },
        .{ .name = "status", .value = request.status },
        .{ .name = "starting_after", .value = request.starting_after },
        .{ .name = "workspace_id", .value = request.workspace_id },
    });
}

pub const ListResponse = common.Response(InternList);
pub fn list(client: anytype, request: ListRequest, request_options: options_mod.RequestOptions) !ListResponse {
    return listWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, request, request_options);
}
pub fn listWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, request: ListRequest, request_options: options_mod.RequestOptions) !ListResponse {
    const path = "/interns";
    const query_string = try listQuery(allocator, request);
    defer allocator.free(query_string);
    return common.execute(ListResponse.Payload, allocator, config, transport, .{ .method = .GET, .path = path, .query = query_string }, request_options);
}
pub const CreateResponse = common.Response(Intern);
pub fn create(client: anytype, request: CreateRequest, request_options: options_mod.RequestOptions) !CreateResponse {
    return createWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, request, request_options);
}
pub fn createWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, request: CreateRequest, request_options: options_mod.RequestOptions) !CreateResponse {
    const path = "/interns";
    const body = try json.stringifyRequest(allocator, request);
    defer allocator.free(body);
    return common.execute(CreateResponse.Payload, allocator, config, transport, .{ .method = .POST, .path = path, .body = body }, request_options);
}
pub const GetResponse = common.Response(Intern);
pub fn get(client: anytype, id: []const u8, request_options: options_mod.RequestOptions) !GetResponse {
    return getWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, id, request_options);
}
pub fn getWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, id: []const u8, request_options: options_mod.RequestOptions) !GetResponse {
    const encoded_id = try common.segment(allocator, id);
    defer allocator.free(encoded_id);
    const path = try std.fmt.allocPrint(allocator, "/interns/{s}", .{encoded_id});
    defer allocator.free(path);
    return common.execute(GetResponse.Payload, allocator, config, transport, .{ .method = .GET, .path = path }, request_options);
}
pub const UpdateResponse = common.Response(Intern);
pub fn update(client: anytype, id: []const u8, request: UpdateRequest, request_options: options_mod.RequestOptions) !UpdateResponse {
    return updateWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, id, request, request_options);
}
pub fn updateWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, id: []const u8, request: UpdateRequest, request_options: options_mod.RequestOptions) !UpdateResponse {
    const encoded_id = try common.segment(allocator, id);
    defer allocator.free(encoded_id);
    const path = try std.fmt.allocPrint(allocator, "/interns/{s}", .{encoded_id});
    defer allocator.free(path);
    const body = try json.stringifyRequest(allocator, request);
    defer allocator.free(body);
    return common.execute(UpdateResponse.Payload, allocator, config, transport, .{ .method = .PATCH, .path = path, .body = body }, request_options);
}
pub const DeleteResponse = common.Response(struct { deleting: bool });
pub fn delete(client: anytype, id: []const u8, request: DeleteRequest, request_options: options_mod.RequestOptions) !DeleteResponse {
    return deleteWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, id, request, request_options);
}
pub fn deleteWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, id: []const u8, request: DeleteRequest, request_options: options_mod.RequestOptions) !DeleteResponse {
    const encoded_id = try common.segment(allocator, id);
    defer allocator.free(encoded_id);
    const path = try std.fmt.allocPrint(allocator, "/interns/{s}", .{encoded_id});
    defer allocator.free(path);
    const body = try json.stringifyRequest(allocator, request);
    defer allocator.free(body);
    return common.execute(DeleteResponse.Payload, allocator, config, transport, .{ .method = .DELETE, .path = path, .body = body }, request_options);
}
pub const GetDaemonResponse = common.Response(DaemonAccess);
pub fn getDaemon(client: anytype, id: []const u8, request_options: options_mod.RequestOptions) !GetDaemonResponse {
    return getDaemonWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, id, request_options);
}
pub fn getDaemonWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, id: []const u8, request_options: options_mod.RequestOptions) !GetDaemonResponse {
    const encoded_id = try common.segment(allocator, id);
    defer allocator.free(encoded_id);
    const path = try std.fmt.allocPrint(allocator, "/interns/{s}/daemon", .{encoded_id});
    defer allocator.free(path);
    return common.execute(GetDaemonResponse.Payload, allocator, config, transport, .{ .method = .GET, .path = path }, request_options);
}
pub const SignDaemonResponse = common.Response(Signature);
pub fn signDaemon(client: anytype, id: []const u8, request: SignRequest, request_options: options_mod.RequestOptions) !SignDaemonResponse {
    return signDaemonWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, id, request, request_options);
}
pub fn signDaemonWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, id: []const u8, request: SignRequest, request_options: options_mod.RequestOptions) !SignDaemonResponse {
    const encoded_id = try common.segment(allocator, id);
    defer allocator.free(encoded_id);
    const path = try std.fmt.allocPrint(allocator, "/interns/{s}/daemon/sign", .{encoded_id});
    defer allocator.free(path);
    const body = try json.stringifyRequest(allocator, request);
    defer allocator.free(body);
    return common.execute(SignDaemonResponse.Payload, allocator, config, transport, .{ .method = .POST, .path = path, .body = body }, request_options);
}
pub const InvokeResponse = common.Response(Accepted);
pub fn invoke(client: anytype, id: []const u8, request: InvokeRequest, request_options: options_mod.RequestOptions) !InvokeResponse {
    return invokeWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, id, request, request_options);
}
pub fn invokeWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, id: []const u8, request: InvokeRequest, request_options: options_mod.RequestOptions) !InvokeResponse {
    const encoded_id = try common.segment(allocator, id);
    defer allocator.free(encoded_id);
    const path = try std.fmt.allocPrint(allocator, "/interns/{s}/invoke", .{encoded_id});
    defer allocator.free(path);
    const body = try json.stringifyRequest(allocator, request);
    defer allocator.free(body);
    return common.execute(InvokeResponse.Payload, allocator, config, transport, .{ .method = .POST, .path = path, .body = body }, request_options);
}
pub const ProvisionResponse = common.Response(struct { provisioning: bool });
pub fn provision(client: anytype, id: []const u8, request_options: options_mod.RequestOptions) !ProvisionResponse {
    return provisionWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, id, request_options);
}
pub fn provisionWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, id: []const u8, request_options: options_mod.RequestOptions) !ProvisionResponse {
    const encoded_id = try common.segment(allocator, id);
    defer allocator.free(encoded_id);
    const path = try std.fmt.allocPrint(allocator, "/interns/{s}/provision", .{encoded_id});
    defer allocator.free(path);
    return common.execute(ProvisionResponse.Payload, allocator, config, transport, .{ .method = .POST, .path = path }, request_options);
}
pub const SuspendResponse = common.Response(struct { suspended: bool });
pub fn suspendIntern(client: anytype, id: []const u8, request_options: options_mod.RequestOptions) !SuspendResponse {
    return suspendInternWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, id, request_options);
}
pub fn suspendInternWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, id: []const u8, request_options: options_mod.RequestOptions) !SuspendResponse {
    const encoded_id = try common.segment(allocator, id);
    defer allocator.free(encoded_id);
    const path = try std.fmt.allocPrint(allocator, "/interns/{s}/suspend", .{encoded_id});
    defer allocator.free(path);
    return common.execute(SuspendResponse.Payload, allocator, config, transport, .{ .method = .POST, .path = path }, request_options);
}

const sse = @import("sse.zig");
pub const ApprovalMode = enum { manual, @"self-drive" };
pub const Message = struct {
    role: enum { system, developer, user, assistant, tool },
    content: ?@import("chat.zig").MessageContent = null,
    tool_call_id: ?[]const u8 = null,
    tool_calls: ?[]const EchoedToolCall = null,
};
pub const EchoedToolCall = struct { id: []const u8, function: struct { name: []const u8, arguments: []const u8 } };
pub const ChatRequest = struct {
    messages: []const Message,
    session_id: ?[]const u8 = null,
    model: ?[]const u8 = null,
    /// Omission uses the server default (self-drive). Repeat manual for each
    /// new run that should ask for tool approvals.
    approval_mode: ?ApprovalMode = null,
};
pub const ChatError = struct { code: i64, message: []const u8, metadata: struct { reason: []const u8, retryable: bool } };
pub const ChatUsage = struct {
    prompt_tokens: u64,
    completion_tokens: u64,
    total_tokens: u64,
    cost: ?f64 = null,
    prompt_tokens_details: ?struct { cached_tokens: u64 } = null,
};
pub const ChatChunk = struct {
    id: []const u8,
    model: []const u8,
    object: []const u8,
    created: i64,
    choices: []struct {
        index: u32,
        finish_reason: ?[]const u8,
        delta: struct {
            role: ?[]const u8 = null,
            content: ?[]const u8 = null,
            reasoning: ?[]const u8 = null,
            tool_calls: ?[]struct { index: u32, id: []const u8, type: []const u8, function: struct { name: []const u8, arguments: []const u8 } } = null,
        },
    },
    session_id: ?[]const u8 = null,
    usage: ?ChatUsage = null,
    @"error": ?ChatError = null,
};
pub const ChatEvent = struct {
    arena: std.heap.ArenaAllocator,
    value: ChatChunk,
    pub fn deinit(self: *@This()) void {
        self.arena.deinit();
        self.* = undefined;
    }
};
pub fn parseChatEvent(allocator: std.mem.Allocator, payload: []const u8) !ChatEvent {
    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const value = try json.parseResponseLeaky(ChatChunk, arena.allocator(), try arena.allocator().dupe(u8, payload));
    return .{ .arena = arena, .value = value };
}
pub const ChatStream = struct {
    state: *sse.State,
    /// Includes final empty-choice events carrying session_id and usage.
    pub fn next(self: *@This()) !?ChatEvent {
        const payload = try self.state.nextDataEvent() orelse return null;
        defer self.state.allocator.free(payload);
        return parseChatEvent(self.state.allocator, payload) catch |err| {
            self.state.done = true;
            return err;
        };
    }
    pub fn deinit(self: *@This()) void {
        self.state.deinit();
        self.* = undefined;
    }
};
pub const SteeredResponse = common.Response(Accepted);
pub const ChatResponse = union(enum) {
    stream: ChatStream,
    steered: SteeredResponse,
    pub fn deinit(self: *@This()) void {
        switch (self.*) {
            inline else => |*v| v.deinit(),
        }
        self.* = undefined;
    }
};
fn chatBody(allocator: std.mem.Allocator, request: ChatRequest) ![]u8 {
    if (request.messages.len == 0) return error.InvalidRequest;
    const last = request.messages[request.messages.len - 1];
    if (last.role == .tool and (request.session_id == null or last.tool_call_id == null)) return error.InvalidRequest;
    return json.stringifyRequest(allocator, .{
        .messages = request.messages,
        .session_id = request.session_id,
        .model = request.model,
        .approval_mode = request.approval_mode,
        .stream = true,
    });
}
pub fn chat(client: anytype, id: []const u8, request: ChatRequest, request_options: options_mod.RequestOptions) !ChatResponse {
    return chatWithHttpClient(client.allocator, &client.http_client, client.config, id, request, request_options);
}
pub fn chatWithHttpClient(allocator: std.mem.Allocator, client: *std.http.Client, config: config_mod.Config, id: []const u8, request: ChatRequest, request_options: options_mod.RequestOptions) !ChatResponse {
    const encoded = try common.segment(allocator, id);
    defer allocator.free(encoded);
    const path = try std.fmt.allocPrint(allocator, "/interns/{s}/chat/completions", .{encoded});
    defer allocator.free(path);
    const body = try chatBody(allocator, request);
    errdefer allocator.free(body);
    var prepared = try http.prepareRequest(allocator, config, .{ .method = .POST, .path = path, .body = body, .accept = "text/event-stream" }, request_options);
    errdefer prepared.deinit();
    const headers = try allocator.alloc(std.http.Header, prepared.headers.len);
    errdefer allocator.free(headers);
    for (prepared.headers, headers) |h, *out| out.* = .{ .name = h.name, .value = h.value };
    var req = try client.request(.POST, try std.Uri.parse(prepared.url), .{ .extra_headers = headers, .redirect_behavior = .unhandled });
    errdefer req.deinit();
    try req.sendBodyComplete(body);
    var response = try req.receiveHead(&.{});
    if (@backingInt(response.head.status) >= 400) return error.ApiError;
    if (response.head.status == .accepted) {
        var buffer: [4096]u8 = undefined;
        var text: std.Io.Writer.Allocating = .init(allocator);
        defer text.deinit();
        _ = try response.reader(&buffer).streamRemaining(&text.writer);
        const steered = try parseSteeredResponse(allocator, response.head, text.written());
        req.deinit();
        allocator.free(headers);
        prepared.deinit();
        allocator.free(body);
        return .{ .steered = steered };
    }
    if (response.head.status != .ok) return error.ApiError;
    const state = try allocator.create(sse.State);
    state.* = .{ .allocator = allocator, .body = body, .prepared = prepared, .std_headers = headers, .request = req, .response = response, .reader = undefined };
    state.initReader();
    return .{ .stream = .{ .state = state } };
}

fn parseSteeredResponse(allocator: std.mem.Allocator, head: std.http.Client.Response.Head, payload: []const u8) !SteeredResponse {
    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const a = arena.allocator();
    const value = try json.parseResponseLeaky(Accepted, a, try a.dupe(u8, payload));
    const metadata = try http.ResponseMetadata.fromHead(a, head);
    return .{ .arena = arena, .value = value, .response_metadata = metadata };
}

test "list uses scoped escaped path and parses 200" {
    const Transport = struct {
        pub fn execute(_: @This(), allocator: std.mem.Allocator, prepared: http.PreparedRequest) !http.HttpResponse {
            try std.testing.expectEqual(std.http.Method.GET, prepared.method);
            try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/interns?status=running%2Cqueued&starting_after=opaque%2F%3F&workspace_id=ws", prepared.url);
            try std.testing.expect(prepared.body == null);
            return (http.FakeTransport{ .status = @fromBackingInt(200), .body = "{\"data\":[{\"attached_vault_id\":null,\"created_at\":\"2026-09-16T08:30:00.000Z\",\"description\":\"Researches customer questions\",\"hostname\":\"research-assistant.openrouter.ai\",\"id\":\"7c9e6679-7425-40de-944b-e07fc1f90ae7\",\"instructions\":null,\"last_failure_message\":null,\"model\":\"openai/gpt-5.4\",\"name\":\"research-assistant\",\"progress\":null,\"status\":\"running\",\"updated_at\":\"2026-09-16T08:45:00.000Z\",\"vault_id\":\"b431c59d-6eed-41ac-bc89-9a89be79a121\",\"workspace_id\":\"89f9f5b2-3f89-4eaf-83ca-5ceae149e8bb\"}],\"has_more\":false}", .headers = &.{.{ .name = "x-request-id", .value = "owned" }} }).execute(allocator, prepared);
        }
    };
    var result = try listWithTransport(std.testing.allocator, .{ .api_key = "test" }, Transport{}, .{ .status = "running,queued", .starting_after = "opaque/?", .workspace_id = "ws" }, .{});
    defer result.deinit();
    try std.testing.expectEqualStrings("owned", result.response_metadata.request_id.?);
    try std.testing.expectError(error.ApiError, listWithTransport(std.testing.allocator, .{ .api_key = "test" }, http.FakeTransport{ .status = .forbidden }, .{ .status = "running,queued", .starting_after = "opaque/?", .workspace_id = "ws" }, .{}));
}
test "create uses scoped escaped path and parses 200" {
    const Transport = struct {
        pub fn execute(_: @This(), allocator: std.mem.Allocator, prepared: http.PreparedRequest) !http.HttpResponse {
            try std.testing.expectEqual(std.http.Method.POST, prepared.method);
            try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/interns", prepared.url);
            var parsed = try json.parseResponse(std.json.Value, allocator, prepared.body.?);
            defer parsed.deinit();
            try std.testing.expect(parsed.value.object.contains("workspace_id"));
            return (http.FakeTransport{ .status = @fromBackingInt(200), .body = "{\"attached_vault_id\":null,\"created_at\":\"2026-09-16T08:30:00.000Z\",\"description\":\"Researches customer questions\",\"hostname\":\"research-assistant.openrouter.ai\",\"id\":\"7c9e6679-7425-40de-944b-e07fc1f90ae7\",\"instructions\":null,\"last_failure_message\":null,\"model\":\"openai/gpt-5.4\",\"name\":\"research-assistant\",\"progress\":null,\"status\":\"running\",\"updated_at\":\"2026-09-16T08:45:00.000Z\",\"vault_id\":\"b431c59d-6eed-41ac-bc89-9a89be79a121\",\"workspace_id\":\"89f9f5b2-3f89-4eaf-83ca-5ceae149e8bb\"}", .headers = &.{.{ .name = "x-request-id", .value = "owned" }} }).execute(allocator, prepared);
        }
    };
    var result = try createWithTransport(std.testing.allocator, .{ .api_key = "test" }, Transport{}, .{ .name = "assistant", .workspace_id = "ws", .provision = false }, .{});
    defer result.deinit();
    try std.testing.expectEqualStrings("owned", result.response_metadata.request_id.?);
    try std.testing.expectError(error.ApiError, createWithTransport(std.testing.allocator, .{ .api_key = "test" }, http.FakeTransport{ .status = .forbidden }, .{ .name = "assistant", .workspace_id = "ws", .provision = false }, .{}));
}
test "get uses scoped escaped path and parses 200" {
    const Transport = struct {
        pub fn execute(_: @This(), allocator: std.mem.Allocator, prepared: http.PreparedRequest) !http.HttpResponse {
            try std.testing.expectEqual(std.http.Method.GET, prepared.method);
            try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/interns/a%2Fb", prepared.url);
            try std.testing.expect(prepared.body == null);
            return (http.FakeTransport{ .status = @fromBackingInt(200), .body = "{\"attached_vault_id\":null,\"created_at\":\"2026-09-16T08:30:00.000Z\",\"description\":\"Researches customer questions\",\"hostname\":\"research-assistant.openrouter.ai\",\"id\":\"7c9e6679-7425-40de-944b-e07fc1f90ae7\",\"instructions\":null,\"last_failure_message\":null,\"model\":\"openai/gpt-5.4\",\"name\":\"research-assistant\",\"progress\":null,\"status\":\"running\",\"updated_at\":\"2026-09-16T08:45:00.000Z\",\"vault_id\":\"b431c59d-6eed-41ac-bc89-9a89be79a121\",\"workspace_id\":\"89f9f5b2-3f89-4eaf-83ca-5ceae149e8bb\"}", .headers = &.{.{ .name = "x-request-id", .value = "owned" }} }).execute(allocator, prepared);
        }
    };
    var result = try getWithTransport(std.testing.allocator, .{ .api_key = "test" }, Transport{}, "a/b", .{});
    defer result.deinit();
    try std.testing.expectEqualStrings("owned", result.response_metadata.request_id.?);
    try std.testing.expectError(error.ApiError, getWithTransport(std.testing.allocator, .{ .api_key = "test" }, http.FakeTransport{ .status = .forbidden }, "a/b", .{}));
}
test "update uses scoped escaped path and parses 200" {
    const Transport = struct {
        pub fn execute(_: @This(), allocator: std.mem.Allocator, prepared: http.PreparedRequest) !http.HttpResponse {
            try std.testing.expectEqual(std.http.Method.PATCH, prepared.method);
            try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/interns/a%2Fb", prepared.url);
            var parsed = try json.parseResponse(std.json.Value, allocator, prepared.body.?);
            defer parsed.deinit();
            try std.testing.expect(parsed.value.object.contains("model"));
            try std.testing.expect(parsed.value.object.get("model").? == .null);
            try std.testing.expect(!parsed.value.object.contains("instructions"));
            return (http.FakeTransport{ .status = @fromBackingInt(200), .body = "{\"attached_vault_id\":null,\"created_at\":\"2026-09-16T08:30:00.000Z\",\"description\":\"Researches customer questions\",\"hostname\":\"research-assistant.openrouter.ai\",\"id\":\"7c9e6679-7425-40de-944b-e07fc1f90ae7\",\"instructions\":null,\"last_failure_message\":null,\"model\":\"openai/gpt-5.4\",\"name\":\"research-assistant\",\"progress\":null,\"status\":\"running\",\"updated_at\":\"2026-09-16T08:45:00.000Z\",\"vault_id\":\"b431c59d-6eed-41ac-bc89-9a89be79a121\",\"workspace_id\":\"89f9f5b2-3f89-4eaf-83ca-5ceae149e8bb\"}", .headers = &.{.{ .name = "x-request-id", .value = "owned" }} }).execute(allocator, prepared);
        }
    };
    var result = try updateWithTransport(std.testing.allocator, .{ .api_key = "test" }, Transport{}, "a/b", .{ .model = .clear, .description = .{ .value = "hello" } }, .{});
    defer result.deinit();
    try std.testing.expectEqualStrings("owned", result.response_metadata.request_id.?);
    try std.testing.expectError(error.ApiError, updateWithTransport(std.testing.allocator, .{ .api_key = "test" }, http.FakeTransport{ .status = .forbidden }, "a/b", .{ .model = .clear, .description = .{ .value = "hello" } }, .{}));
}
test "delete uses scoped escaped path and parses 202" {
    const Transport = struct {
        pub fn execute(_: @This(), allocator: std.mem.Allocator, prepared: http.PreparedRequest) !http.HttpResponse {
            try std.testing.expectEqual(std.http.Method.DELETE, prepared.method);
            try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/interns/a%2Fb", prepared.url);
            var parsed = try json.parseResponse(std.json.Value, allocator, prepared.body.?);
            defer parsed.deinit();
            try std.testing.expect(parsed.value.object.contains("acknowledge_workspace_loss"));
            try std.testing.expect(!parsed.value.object.get("acknowledge_workspace_loss").?.bool);
            return (http.FakeTransport{ .status = @fromBackingInt(202), .body = "{\"deleting\":true}", .headers = &.{.{ .name = "x-request-id", .value = "owned" }} }).execute(allocator, prepared);
        }
    };
    var result = try deleteWithTransport(std.testing.allocator, .{ .api_key = "test" }, Transport{}, "a/b", .{}, .{});
    defer result.deinit();
    try std.testing.expectEqualStrings("owned", result.response_metadata.request_id.?);
    try std.testing.expectError(error.ApiError, deleteWithTransport(std.testing.allocator, .{ .api_key = "test" }, http.FakeTransport{ .status = .forbidden }, "a/b", .{}, .{}));
}
test "getDaemon uses scoped escaped path and parses 200" {
    const Transport = struct {
        pub fn execute(_: @This(), allocator: std.mem.Allocator, prepared: http.PreparedRequest) !http.HttpResponse {
            try std.testing.expectEqual(std.http.Method.GET, prepared.method);
            try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/interns/a%2Fb/daemon", prepared.url);
            try std.testing.expect(prepared.body == null);
            return (http.FakeTransport{ .status = @fromBackingInt(200), .body = "{\"origin\":\"https://research-assistant-7c9e6679.or.bot\",\"token\":\"daemon_token\"}", .headers = &.{.{ .name = "x-request-id", .value = "owned" }} }).execute(allocator, prepared);
        }
    };
    var result = try getDaemonWithTransport(std.testing.allocator, .{ .api_key = "test" }, Transport{}, "a/b", .{});
    defer result.deinit();
    try std.testing.expectEqualStrings("owned", result.response_metadata.request_id.?);
    try std.testing.expectError(error.ApiError, getDaemonWithTransport(std.testing.allocator, .{ .api_key = "test" }, http.FakeTransport{ .status = .forbidden }, "a/b", .{}));
}
test "signDaemon uses scoped escaped path and parses 200" {
    const Transport = struct {
        pub fn execute(_: @This(), allocator: std.mem.Allocator, prepared: http.PreparedRequest) !http.HttpResponse {
            try std.testing.expectEqual(std.http.Method.POST, prepared.method);
            try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/interns/a%2Fb/daemon/sign", prepared.url);
            var parsed = try json.parseResponse(std.json.Value, allocator, prepared.body.?);
            defer parsed.deinit();
            try std.testing.expect(parsed.value.object.contains("bodySha256"));
            return (http.FakeTransport{ .status = @fromBackingInt(200), .body = "{\"x-ori-invoke-signature\":\"MEUCIQ...\",\"x-ori-invoke-timestamp\":\"1789000000\",\"x-ori-invoke-user\":\"user_2abc\"}", .headers = &.{.{ .name = "x-request-id", .value = "owned" }} }).execute(allocator, prepared);
        }
    };
    var result = try signDaemonWithTransport(std.testing.allocator, .{ .api_key = "test" }, Transport{}, "a/b", .{ .bodySha256 = "digest" }, .{});
    defer result.deinit();
    try std.testing.expectEqualStrings("owned", result.response_metadata.request_id.?);
    try std.testing.expectError(error.ApiError, signDaemonWithTransport(std.testing.allocator, .{ .api_key = "test" }, http.FakeTransport{ .status = .forbidden }, "a/b", .{ .bodySha256 = "digest" }, .{}));
}
test "invoke uses scoped escaped path and parses 202" {
    const Transport = struct {
        pub fn execute(_: @This(), allocator: std.mem.Allocator, prepared: http.PreparedRequest) !http.HttpResponse {
            try std.testing.expectEqual(std.http.Method.POST, prepared.method);
            try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/interns/a%2Fb/invoke", prepared.url);
            var parsed = try json.parseResponse(std.json.Value, allocator, prepared.body.?);
            defer parsed.deinit();
            try std.testing.expect(parsed.value.object.contains("session_id"));
            return (http.FakeTransport{ .status = @fromBackingInt(202), .body = "{\"session_id\":\"b51a0e21-368b-4780-a220-14655bf28c55\",\"status\":\"started\"}", .headers = &.{.{ .name = "x-request-id", .value = "owned" }} }).execute(allocator, prepared);
        }
    };
    var result = try invokeWithTransport(std.testing.allocator, .{ .api_key = "test" }, Transport{}, "a/b", .{ .input = "hello", .session_id = "session" }, .{});
    defer result.deinit();
    try std.testing.expectEqualStrings("owned", result.response_metadata.request_id.?);
    try std.testing.expectError(error.ApiError, invokeWithTransport(std.testing.allocator, .{ .api_key = "test" }, http.FakeTransport{ .status = .forbidden }, "a/b", .{ .input = "hello", .session_id = "session" }, .{}));
}
test "provision uses scoped escaped path and parses 202" {
    const Transport = struct {
        pub fn execute(_: @This(), allocator: std.mem.Allocator, prepared: http.PreparedRequest) !http.HttpResponse {
            try std.testing.expectEqual(std.http.Method.POST, prepared.method);
            try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/interns/a%2Fb/provision", prepared.url);
            try std.testing.expect(prepared.body == null);
            return (http.FakeTransport{ .status = @fromBackingInt(202), .body = "{\"provisioning\":true}", .headers = &.{.{ .name = "x-request-id", .value = "owned" }} }).execute(allocator, prepared);
        }
    };
    var result = try provisionWithTransport(std.testing.allocator, .{ .api_key = "test" }, Transport{}, "a/b", .{});
    defer result.deinit();
    try std.testing.expectEqualStrings("owned", result.response_metadata.request_id.?);
    try std.testing.expectError(error.ApiError, provisionWithTransport(std.testing.allocator, .{ .api_key = "test" }, http.FakeTransport{ .status = .forbidden }, "a/b", .{}));
}
test "suspendIntern uses scoped escaped path and parses 200" {
    const Transport = struct {
        pub fn execute(_: @This(), allocator: std.mem.Allocator, prepared: http.PreparedRequest) !http.HttpResponse {
            try std.testing.expectEqual(std.http.Method.POST, prepared.method);
            try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/interns/a%2Fb/suspend", prepared.url);
            try std.testing.expect(prepared.body == null);
            return (http.FakeTransport{ .status = @fromBackingInt(200), .body = "{\"suspended\":true}", .headers = &.{.{ .name = "x-request-id", .value = "owned" }} }).execute(allocator, prepared);
        }
    };
    var result = try suspendInternWithTransport(std.testing.allocator, .{ .api_key = "test" }, Transport{}, "a/b", .{});
    defer result.deinit();
    try std.testing.expectEqualStrings("owned", result.response_metadata.request_id.?);
    try std.testing.expectError(error.ApiError, suspendInternWithTransport(std.testing.allocator, .{ .api_key = "test" }, http.FakeTransport{ .status = .forbidden }, "a/b", .{}));
}

test "intern chat forces streaming and validates tool reply context before network" {
    const body = try chatBody(std.testing.allocator, .{ .messages = &.{.{ .role = .user, .content = .{ .text = "hello" } }}, .approval_mode = .manual });
    defer std.testing.allocator.free(body);
    var parsed = try json.parseResponse(std.json.Value, std.testing.allocator, body);
    defer parsed.deinit();
    try std.testing.expect(parsed.value.object.get("stream").?.bool);
    try std.testing.expectEqualStrings("manual", parsed.value.object.get("approval_mode").?.string);
    var client: std.http.Client = .{ .allocator = std.testing.allocator, .io = std.testing.io };
    defer client.deinit();
    try std.testing.expectError(error.InvalidRequest, chatWithHttpClient(std.testing.allocator, &client, .{ .api_key = "test" }, "intern", .{ .messages = &.{} }, .{}));
    try std.testing.expectError(error.InvalidRequest, chatBody(std.testing.allocator, .{ .messages = &.{.{ .role = .tool, .content = .{ .text = "allow_once" }, .tool_call_id = "interaction" }} }));
}

test "intern chat stream retains tool interactions errors and final session usage" {
    const data =
        "data: {\"id\":\"c\",\"model\":\"runtime\",\"object\":\"chat.completion.chunk\",\"created\":1,\"choices\":[{\"index\":0,\"finish_reason\":\"tool_calls\",\"delta\":{\"tool_calls\":[{\"id\":\"interaction\",\"index\":0,\"type\":\"function\",\"function\":{\"name\":\"openrouter.provide_input\",\"arguments\":\"{}\"}}]}}]}\n\n" ++
        "data: {\"id\":\"c\",\"model\":\"runtime\",\"object\":\"chat.completion.chunk\",\"created\":1,\"choices\":[{\"index\":0,\"finish_reason\":\"error\",\"delta\":{}}],\"error\":{\"code\":502,\"message\":\"Lost\",\"metadata\":{\"reason\":\"stream_severed\",\"retryable\":true}}}\n\n" ++
        "data: {\"id\":\"c\",\"model\":\"runtime\",\"object\":\"chat.completion.chunk\",\"created\":1,\"choices\":[],\"session_id\":\"continue-me\",\"usage\":{\"prompt_tokens\":2,\"completion_tokens\":3,\"total_tokens\":5}}\n\n" ++
        "data: [DONE]\n\n";
    var reader: std.Io.Reader = .fixed(data);
    // Only the SSE reader is used; no socket is needed for this stream fixture.
    var state: sse.State = .{ .allocator = std.testing.allocator, .body = undefined, .prepared = undefined, .std_headers = undefined, .request = undefined, .response = undefined, .reader = &reader };
    var stream: ChatStream = .{ .state = &state };
    var tool = (try stream.next()).?;
    defer tool.deinit();
    try std.testing.expectEqualStrings("interaction", tool.value.choices[0].delta.tool_calls.?[0].id);
    var failure = (try stream.next()).?;
    defer failure.deinit();
    try std.testing.expect(failure.value.@"error".?.metadata.retryable);
    var final = (try stream.next()).?;
    defer final.deinit();
    try std.testing.expectEqual(@as(usize, 0), final.value.choices.len);
    try std.testing.expectEqualStrings("continue-me", final.value.session_id.?);
    try std.testing.expectEqual(@as(u64, 5), final.value.usage.?.total_tokens);
    try std.testing.expect(try stream.next() == null);
}

test "intern chat malformed events stop iteration" {
    var reader: std.Io.Reader = .fixed("data: {}\n\n");
    var state: sse.State = .{ .allocator = std.testing.allocator, .body = undefined, .prepared = undefined, .std_headers = undefined, .request = undefined, .response = undefined, .reader = &reader };
    var stream: ChatStream = .{ .state = &state };
    try std.testing.expectError(error.MissingField, stream.next());
    try std.testing.expect(try stream.next() == null);
}

test "intern chat steering response owns session and response headers" {
    const head = try std.http.Client.Response.Head.parse("HTTP/1.1 202 Accepted\r\nContent-Type: application/json\r\nX-Request-Id: steering-request\r\n\r\n");
    var result = try parseSteeredResponse(std.testing.allocator, head, "{\"status\":\"steered\",\"session_id\":\"running-session\"}");
    defer result.deinit();
    try std.testing.expectEqualStrings("steered", result.value.status);
    try std.testing.expectEqualStrings("running-session", result.value.session_id);
    try std.testing.expectEqualStrings("steering-request", result.response_metadata.request_id.?);
    try std.testing.expectError(error.MissingField, parseSteeredResponse(std.testing.allocator, head, "{}"));
}
