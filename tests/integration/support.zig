const std = @import("std");
const openrouter = @import("openrouter");

pub fn env(name: []const u8) ?[]const u8 {
    var i: usize = 0;
    while (std.c.environ[i]) |entry| : (i += 1) {
        const item = std.mem.span(entry);
        if (item.len > name.len and item[name.len] == '=' and std.mem.eql(u8, item[0..name.len], name)) {
            return item[name.len + 1 ..];
        }
    }
    return null;
}

pub fn envFlag(name: []const u8) bool {
    const value = env(name) orelse return false;
    return std.mem.eql(u8, value, "1") or std.mem.eql(u8, value, "true") or std.mem.eql(u8, value, "yes");
}

pub fn initPublicClient(threaded: *std.Io.Threaded) !openrouter.Client {
    const api_key = env("OPENROUTER_API_KEY") orelse return error.SkipZigTest;
    return try initClient(threaded, api_key);
}

pub fn initManagementClient(threaded: *std.Io.Threaded) !openrouter.Client {
    const api_key = env("OPENROUTER_MANAGEMENT_API_KEY") orelse return error.SkipZigTest;
    return try initClient(threaded, api_key);
}

pub fn initClient(threaded: *std.Io.Threaded, api_key: []const u8) !openrouter.Client {
    const allocator = std.testing.allocator;

    return try openrouter.Client.init(allocator, threaded.io(), .{
        .api_key = api_key,
        .http_referer = env("OPENROUTER_HTTP_REFERER"),
        .x_title = env("OPENROUTER_APP_TITLE"),
        .retry = .{ .max_attempts = 1 },
    });
}

pub const Group = enum { discovery, chat, standard, management };

pub fn allowsProfile(profile: []const u8, group: Group) !bool {
    if (std.mem.eql(u8, profile, "free")) return group == .discovery or group == .chat;
    if (std.mem.eql(u8, profile, "management")) return group == .management;
    if (std.mem.eql(u8, profile, "paid")) return group != .management;
    return error.InvalidTestProfile;
}

pub fn requireProfile(group: Group) !void {
    const profile = env("OPENROUTER_TEST_PROFILE") orelse return;
    if (!try allowsProfile(profile, group)) return error.SkipZigTest;
}

pub fn freeModelAllowed(model: []const u8) bool {
    return std.mem.eql(u8, model, "openrouter/free") or std.mem.endsWith(u8, model, ":free");
}

pub fn isFreeProfile() bool {
    return std.mem.eql(u8, env("OPENROUTER_TEST_PROFILE") orelse "", "free");
}

pub fn chatModel() ![]const u8 {
    const fallback = if (isFreeProfile()) "openrouter/free" else "openai/gpt-4o-mini";
    const model = env("OPENROUTER_CHAT_MODEL") orelse fallback;
    if (isFreeProfile() and !freeModelAllowed(model)) return error.PaidModelInFreeProfile;
    return model;
}

pub fn prepareChat(client: *openrouter.Client, io: std.Io) !void {
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

/// Protocol-specific overrides must obey the same free-model restriction as chat.
pub fn protocolModel(variable: []const u8, paid_default: []const u8) ![]const u8 {
    const model = env(variable) orelse if (isFreeProfile()) try chatModel() else paid_default;
    if (isFreeProfile() and !freeModelAllowed(model)) return error.PaidModelInFreeProfile;
    return model;
}

pub fn tokenLimitedResponse(response: ?std.json.Value) bool {
    const value = response orelse return false;
    if (value != .object) return false;
    const details = value.object.get("incomplete_details") orelse return false;
    if (details != .object) return false;
    const reason = details.object.get("reason") orelse return false;
    return reason == .string and std.mem.eql(u8, reason.string, "max_output_tokens");
}

test "Responses token-limit handling accepts only the documented reason" {
    var limited = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, "{\"incomplete_details\":{\"reason\":\"max_output_tokens\"}}", .{});
    defer limited.deinit();
    try std.testing.expect(tokenLimitedResponse(limited.value));
    var failed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, "{\"incomplete_details\":{\"reason\":\"content_filter\"}}", .{});
    defer failed.deinit();
    try std.testing.expect(!tokenLimitedResponse(failed.value));
    try std.testing.expect(!tokenLimitedResponse(null));
}
