const std = @import("std");
const openrouter = @import("openrouter");

test "list models integration" {
    try requireProfile(.discovery);
    var threaded: std.Io.Threaded = .init_single_threaded;
    defer threaded.deinit();

    var client = try initPublicClient(&threaded);
    defer client.deinit();

    var response = try client.models.list(.{});
    defer response.deinit();

    try std.testing.expect(response.data.len > 0);
}

test "models count integration" {
    try requireProfile(.discovery);
    var threaded: std.Io.Threaded = .init_single_threaded;
    defer threaded.deinit();

    var client = try initPublicClient(&threaded);
    defer client.deinit();

    var response = try client.models.count(.{}, .{});
    defer response.deinit();

    try std.testing.expect(response.data.count > 0);
}

test "providers list integration" {
    try requireProfile(.discovery);
    var threaded: std.Io.Threaded = .init_single_threaded;
    defer threaded.deinit();

    var client = try initPublicClient(&threaded);
    defer client.deinit();

    var response = try client.providers.list(.{});
    defer response.deinit();

    try std.testing.expect(response.data.len > 0);
}

test "datasets rankings daily integration" {
    try requireProfile(.standard);
    var threaded: std.Io.Threaded = .init_single_threaded;
    defer threaded.deinit();

    var client = try initPublicClient(&threaded);
    defer client.deinit();

    var response = try client.datasets.rankings_daily.get(.{}, .{});
    defer response.deinit();

    try std.testing.expect(response.data.len > 0);
}

test "generation integration" {
    try requireProfile(.standard);
    var threaded: std.Io.Threaded = .init_single_threaded;
    defer threaded.deinit();

    const generation_id = env("OPENROUTER_GENERATION_ID") orelse return error.SkipZigTest;
    var client = try initPublicClient(&threaded);
    defer client.deinit();

    var response = try client.generation.get(.{ .id = generation_id }, .{});
    defer response.deinit();

    try std.testing.expect(response.data.id.len > 0);
}

test "generation content integration" {
    try requireProfile(.standard);
    var threaded: std.Io.Threaded = .init_single_threaded;
    defer threaded.deinit();

    const generation_id = env("OPENROUTER_GENERATION_ID") orelse return error.SkipZigTest;
    var client = try initPublicClient(&threaded);
    defer client.deinit();

    var response = try client.generation.content(.{ .id = generation_id }, .{});
    defer response.deinit();

    try std.testing.expect(response.data.input.prompt != null or response.data.input.messages != null);
}

test "chat streaming integration" {
    try requireProfile(.chat);
    var threaded: std.Io.Threaded = .init_single_threaded;
    defer threaded.deinit();

    var client = try initPublicClient(&threaded);
    defer client.deinit();

    try prepareChat(&client, threaded.io());
    var response = try client.chat.completions.stream(.{
        .model = try chatModel(),
        .messages = &.{openrouter.ChatMessage{
            .role = .user,
            .content = .{ .text = "Reply with only: ok" },
        }},
        .max_tokens = 64,
    }, .{});
    defer response.deinit();

    var chunks_seen: usize = 0;
    var saw_content = false;
    var saw_finish = false;
    while (chunks_seen < 256) {
        var chunk = (try response.next()) orelse break;
        defer chunk.deinit();

        chunks_seen += 1;
        if (chunk.content()) |text| saw_content = saw_content or text.len > 0;
        for (chunk.choices) |choice| {
            if (choice.delta.reasoning) |text| saw_content = saw_content or text.len > 0;
            if (choice.finish_reason != null) saw_finish = true;
        }
    }

    try std.testing.expect(chunks_seen > 0);
    try std.testing.expect(saw_content);
    if (!saw_finish) return error.StreamLimitExceeded;
}

test "chat Fusion plugin integration" {
    try requireProfile(.standard);
    if (!envFlag("OPENROUTER_FUSION_TEST")) return error.SkipZigTest;

    var threaded: std.Io.Threaded = .init_single_threaded;
    defer threaded.deinit();

    var client = try initPublicClient(&threaded);
    defer client.deinit();

    var response = client.chat.completions.create(.{
        .model = env("OPENROUTER_FUSION_MODEL") orelse "openrouter/fusion",
        .messages = &.{openrouter.ChatMessage{
            .role = .user,
            .content = .{ .text = "Answer in one short sentence: what is Fusion useful for?" },
        }},
        .plugins = &.{openrouter.ChatPlugin{ .fusion = .{
            .preset = env("OPENROUTER_FUSION_PRESET") orelse "general-budget",
        } }},
    }, .{}) catch |err| switch (err) {
        error.ApiError => {
            if (envFlag("OPENROUTER_FUSION_STRICT")) return err;
            return error.SkipZigTest;
        },
        else => |e| return e,
    };
    defer response.deinit();

    try std.testing.expect(response.choices.len > 0);
    try std.testing.expect(response.choices[0].message.content != null);
    try std.testing.expect(response.choices[0].message.content.?.len > 0);
}

test "chat server tools integration" {
    try requireProfile(.standard);
    if (!envFlag("OPENROUTER_CHAT_SERVER_TOOLS_TEST")) return error.SkipZigTest;

    var threaded: std.Io.Threaded = .init_single_threaded;
    defer threaded.deinit();

    var client = try initPublicClient(&threaded);
    defer client.deinit();

    var response = client.chat.completions.create(.{
        .model = env("OPENROUTER_CHAT_SERVER_TOOLS_MODEL") orelse "openai/gpt-4o-mini",
        .messages = &.{openrouter.ChatMessage{
            .role = .user,
            .content = .{ .text = "Search ziglang.org and answer in one short sentence: what is Zig?" },
        }},
        .tools = &.{openrouter.ChatServerTool{ .web_search = .{
            .max_results = 3,
            .search_context_size = .medium,
            .allowed_domains = &.{"ziglang.org"},
        } }},
        .tool_choice = .required,
        .max_tokens = 80,
    }, .{}) catch |err| switch (err) {
        error.ApiError => {
            if (envFlag("OPENROUTER_CHAT_SERVER_TOOLS_STRICT")) return err;
            return error.SkipZigTest;
        },
        else => |e| return e,
    };
    defer response.deinit();

    try std.testing.expect(response.choices.len > 0);
    try std.testing.expect(response.choices[0].message.content != null);
    try std.testing.expect(response.choices[0].message.content.?.len > 0);
}

test "messages streaming integration" {
    try requireProfile(.standard);
    var threaded: std.Io.Threaded = .init_single_threaded;
    defer threaded.deinit();

    var client = try initPublicClient(&threaded);
    defer client.deinit();

    var response = try client.messages.stream(.{
        .model = env("OPENROUTER_MESSAGES_MODEL") orelse "anthropic/claude-3.5-haiku",
        .messages = &.{.{
            .role = .user,
            .content = .{ .text = "Reply with only: ok" },
        }},
        .max_tokens = 4,
    }, .{});
    defer response.deinit();

    var events_seen: usize = 0;
    var saw_content = false;
    while (events_seen < 64) {
        var event = (try response.next()) orelse break;
        defer event.deinit();

        events_seen += 1;
        try std.testing.expect(event.type != null or event.message != null or event.delta != null);
        if (event.message != null) saw_content = true;
        if (event.textDelta()) |text| saw_content = saw_content or text.len > 0;
    }

    try std.testing.expect(events_seen > 0);
    try std.testing.expect(saw_content);
}

test "responses streaming integration" {
    try requireProfile(.standard);
    var threaded: std.Io.Threaded = .init_single_threaded;
    defer threaded.deinit();
    var client = try initPublicClient(&threaded);
    defer client.deinit();

    var stream = try client.responses.stream(.{
        .model = env("OPENROUTER_RESPONSES_MODEL") orelse "openai/gpt-4o-mini",
        .input = .{ .text = "Reply with only: ok" },
        .max_output_tokens = 4,
    }, .{});
    defer stream.deinit();

    var events_seen: usize = 0;
    var saw_text = false;
    var saw_success = false;
    while (events_seen < 64) {
        var event = (try stream.next()) orelse break;
        defer event.deinit();
        events_seen += 1;
        if (event.textDelta()) |text| saw_text = saw_text or text.len > 0;
        if (event.isTerminal()) {
            if (!event.isSuccess()) return error.ResponseFailed;
            saw_success = true;
            break;
        }
    }
    if (!saw_success) return error.StreamLimitExceeded;
    try std.testing.expect(events_seen > 0);
    try std.testing.expect(saw_text);
}

test "credits integration with management key" {
    try requireProfile(.management);
    var threaded: std.Io.Threaded = .init_single_threaded;
    defer threaded.deinit();

    var client = try initManagementClient(&threaded);
    defer client.deinit();

    var response = try client.credits.get(.{});
    defer response.deinit();

    try std.testing.expect(response.data.total_credits >= 0);
}

test "BYOK list integration with management key" {
    try requireProfile(.management);
    var threaded: std.Io.Threaded = .init_single_threaded;
    defer threaded.deinit();

    var client = try initManagementClient(&threaded);
    defer client.deinit();

    var response = try client.byok.list(.{ .limit = 10 }, .{});
    defer response.deinit();

    try std.testing.expect(response.data.len == 0 or response.data[0].id != null);
}

test "guardrails list integration with management key" {
    try requireProfile(.management);
    var threaded: std.Io.Threaded = .init_single_threaded;
    defer threaded.deinit();

    var client = try initManagementClient(&threaded);
    defer client.deinit();

    var response = try client.guardrails.list(.{ .limit = 10 }, .{});
    defer response.deinit();

    try std.testing.expect(response.data.len == 0 or response.data[0].id != null);
}

test "workspaces list integration with management key" {
    try requireProfile(.management);
    var threaded: std.Io.Threaded = .init_single_threaded;
    defer threaded.deinit();

    var client = try initManagementClient(&threaded);
    defer client.deinit();

    var response = try client.workspaces.list(.{ .limit = 10 }, .{});
    defer response.deinit();

    try std.testing.expect(response.data.len == 0 or response.data[0].id != null);
}

test "observability destinations list integration with management key" {
    try requireProfile(.management);
    var threaded: std.Io.Threaded = .init_single_threaded;
    defer threaded.deinit();

    var client = try initManagementClient(&threaded);
    defer client.deinit();

    var response = try client.observability.destinations.list(.{ .limit = 10 }, .{});
    defer response.deinit();

    try std.testing.expect(response.data.len == 0 or response.data[0].id != null);
}

test "organization members list integration with management key" {
    try requireProfile(.management);
    var threaded: std.Io.Threaded = .init_single_threaded;
    defer threaded.deinit();

    var client = try initManagementClient(&threaded);
    defer client.deinit();

    var response = try client.organization.members.list(.{ .limit = 10 }, .{});
    defer response.deinit();

    try std.testing.expect(response.data.len == 0 or response.data[0].id != null);
}

test "activity integration with management key" {
    try requireProfile(.management);
    var threaded: std.Io.Threaded = .init_single_threaded;
    defer threaded.deinit();

    var client = try initManagementClient(&threaded);
    defer client.deinit();

    var response = try client.activity.get(.{}, .{});
    defer response.deinit();

    if (response.data.len > 0) {
        try std.testing.expect(response.data[0].date.len > 0);
        try std.testing.expect(response.data[0].model.len > 0);
    }
}

fn env(name: []const u8) ?[]const u8 {
    var i: usize = 0;
    while (std.c.environ[i]) |entry| : (i += 1) {
        const item = std.mem.span(entry);
        if (item.len > name.len and item[name.len] == '=' and std.mem.eql(u8, item[0..name.len], name)) {
            return item[name.len + 1 ..];
        }
    }
    return null;
}

fn envFlag(name: []const u8) bool {
    const value = env(name) orelse return false;
    return std.mem.eql(u8, value, "1") or std.mem.eql(u8, value, "true") or std.mem.eql(u8, value, "yes");
}

fn initPublicClient(threaded: *std.Io.Threaded) !openrouter.Client {
    const api_key = env("OPENROUTER_API_KEY") orelse return error.SkipZigTest;
    return try initClient(threaded, api_key);
}

fn initManagementClient(threaded: *std.Io.Threaded) !openrouter.Client {
    const api_key = env("OPENROUTER_MANAGEMENT_API_KEY") orelse return error.SkipZigTest;
    return try initClient(threaded, api_key);
}

fn initClient(threaded: *std.Io.Threaded, api_key: []const u8) !openrouter.Client {
    const allocator = std.testing.allocator;

    return try openrouter.Client.init(allocator, threaded.io(), .{
        .api_key = api_key,
        .http_referer = env("OPENROUTER_HTTP_REFERER"),
        .x_title = env("OPENROUTER_APP_TITLE"),
        .retry = .{ .max_attempts = 1 },
    });
}

const Group = enum { discovery, chat, standard, management };

fn allowsProfile(profile: []const u8, group: Group) !bool {
    if (std.mem.eql(u8, profile, "free")) return group == .discovery or group == .chat;
    if (std.mem.eql(u8, profile, "management")) return group == .management;
    if (std.mem.eql(u8, profile, "paid")) return group != .management;
    return error.InvalidTestProfile;
}

fn requireProfile(group: Group) !void {
    const profile = env("OPENROUTER_TEST_PROFILE") orelse return;
    if (!try allowsProfile(profile, group)) return error.SkipZigTest;
}

fn freeModelAllowed(model: []const u8) bool {
    return std.mem.eql(u8, model, "openrouter/free") or std.mem.endsWith(u8, model, ":free");
}

fn isFreeProfile() bool {
    return std.mem.eql(u8, env("OPENROUTER_TEST_PROFILE") orelse "", "free");
}

fn chatModel() ![]const u8 {
    const fallback = if (isFreeProfile()) "openrouter/free" else "openai/gpt-4o-mini";
    const model = env("OPENROUTER_CHAT_MODEL") orelse fallback;
    if (isFreeProfile() and !freeModelAllowed(model)) return error.PaidModelInFreeProfile;
    return model;
}

fn prepareChat(client: *openrouter.Client, io: std.Io) !void {
    _ = try chatModel();
    if (!isFreeProfile()) return;
    var key = try client.key.get(.{});
    defer key.deinit();
    if (key.data.free_model_daily_requests) |quota| {
        if (quota.remaining == 0) return error.FreeQuotaExhausted;
    }
    // Pace inference without retrying a whole run or changing credentials.
    try std.Io.sleep(io, .fromMilliseconds(3500), .awake);
}

test "current API key integration" {
    try requireProfile(.discovery);
    var threaded: std.Io.Threaded = .init_single_threaded;
    defer threaded.deinit();
    var client = try initPublicClient(&threaded);
    defer client.deinit();
    var response = try client.key.get(.{});
    defer response.deinit();
    try std.testing.expect(response.data.label.len > 0);
}

test "chat buffered integration" {
    try requireProfile(.chat);
    var threaded: std.Io.Threaded = .init_single_threaded;
    defer threaded.deinit();
    var client = try initPublicClient(&threaded);
    defer client.deinit();
    try prepareChat(&client, threaded.io());
    var response = try client.chat.completions.create(.{
        .model = try chatModel(),
        .messages = &.{.{ .role = .user, .content = .{ .text = "Reply with only: ok" } }},
        .max_tokens = 64,
    }, .{});
    defer response.deinit();
    try std.testing.expect(response.choices.len > 0);
    const choice = response.choices[0];
    try std.testing.expect(choice.finish_reason != null);
    const message = choice.message;
    const has_content = if (message.content) |text| text.len > 0 else false;
    const has_reasoning = if (message.reasoning) |text| text.len > 0 else false;
    try std.testing.expect(has_content or has_reasoning);
}

test "integration profile selection excludes paid inference from free and management" {
    try std.testing.expect(try allowsProfile("free", .discovery));
    try std.testing.expect(try allowsProfile("free", .chat));
    try std.testing.expect(!try allowsProfile("free", .standard));
    try std.testing.expect(!try allowsProfile("free", .management));
    try std.testing.expect(try allowsProfile("management", .management));
    try std.testing.expect(!try allowsProfile("management", .discovery));
    try std.testing.expect(!try allowsProfile("management", .chat));
    try std.testing.expect(!try allowsProfile("management", .standard));
    try std.testing.expect(try allowsProfile("paid", .standard));
    try std.testing.expect(!try allowsProfile("paid", .management));
    try std.testing.expectError(error.InvalidTestProfile, allowsProfile("typo", .chat));
}

test "free model selection rejects paid models and automatic paid routing" {
    try std.testing.expect(freeModelAllowed("openrouter/free"));
    try std.testing.expect(freeModelAllowed("vendor/model:free"));
    try std.testing.expect(!freeModelAllowed("openrouter/auto"));
    try std.testing.expect(!freeModelAllowed("vendor/model"));
}
