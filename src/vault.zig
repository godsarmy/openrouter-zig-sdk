//! Workspace and intern secret management. Requires Intern API programme access; writes may be disabled.
const std = @import("std");
const common = @import("enterprise.zig");
const config_mod = @import("config.zig");
const http = @import("http.zig");
const json = @import("json.zig");
const options_mod = @import("options.zig");
const query = @import("query.zig");
/// API-key workspace selects scope; no fallback. Reads expose metadata only.
pub const Secret = struct { name: []const u8, hosts: ?[][]const u8, fingerprint: ?[]const u8, created_at: []const u8 };
pub const EffectiveSecret = struct { name: []const u8, hosts: ?[][]const u8, fingerprint: ?[]const u8, created_at: []const u8, scope: []const u8 };
pub const SecretList = struct { data: []Secret, has_more: bool };
pub const EffectiveSecretList = struct { data: []EffectiveSecret, has_more: bool };
pub const WriteRequest = struct { value: []const u8, hosts: []const []const u8 };
pub const CopyRequest = struct { names: []const []const u8 };
pub const ListRequest = struct { limit: ?u64 = null, offset: ?u64 = null };
fn listQuery(allocator: std.mem.Allocator, request: ListRequest) ![]u8 {
    var limit: [20]u8 = undefined;
    var offset: [20]u8 = undefined;
    return query.build(allocator, &.{
        .{ .name = "limit", .value = if (request.limit) |v| try std.fmt.bufPrint(&limit, "{d}", .{v}) else null },
        .{ .name = "offset", .value = if (request.offset) |v| try std.fmt.bufPrint(&offset, "{d}", .{v}) else null },
    });
}

pub const ListSecretsResponse = common.Response(SecretList);
pub fn listSecrets(client: anytype, request: ListRequest, request_options: options_mod.RequestOptions) !ListSecretsResponse {
    return listSecretsWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, request, request_options);
}
pub fn listSecretsWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, request: ListRequest, request_options: options_mod.RequestOptions) !ListSecretsResponse {
    const path = "/vault/secrets";
    const query_string = try listQuery(allocator, request);
    defer allocator.free(query_string);
    return common.execute(ListSecretsResponse.Payload, allocator, config, transport, .{ .method = .GET, .path = path, .query = query_string }, request_options);
}
pub const PutSecretResponse = common.Response(struct { data: Secret });
pub fn putSecret(client: anytype, name: []const u8, request: WriteRequest, request_options: options_mod.RequestOptions) !PutSecretResponse {
    return putSecretWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, name, request, request_options);
}
pub fn putSecretWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, name: []const u8, request: WriteRequest, request_options: options_mod.RequestOptions) !PutSecretResponse {
    const encoded_name = try common.segment(allocator, name);
    defer allocator.free(encoded_name);
    const path = try std.fmt.allocPrint(allocator, "/vault/secrets/{s}", .{encoded_name});
    defer allocator.free(path);
    const body = try json.stringifyRequest(allocator, request);
    defer allocator.free(body);
    return common.execute(PutSecretResponse.Payload, allocator, config, transport, .{ .method = .PUT, .path = path, .body = body }, request_options);
}
pub const DeleteSecretResponse = common.Response(void);
pub fn deleteSecret(client: anytype, name: []const u8, request_options: options_mod.RequestOptions) !DeleteSecretResponse {
    return deleteSecretWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, name, request_options);
}
pub fn deleteSecretWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, name: []const u8, request_options: options_mod.RequestOptions) !DeleteSecretResponse {
    const encoded_name = try common.segment(allocator, name);
    defer allocator.free(encoded_name);
    const path = try std.fmt.allocPrint(allocator, "/vault/secrets/{s}", .{encoded_name});
    defer allocator.free(path);
    return common.execute(DeleteSecretResponse.Payload, allocator, config, transport, .{ .method = .DELETE, .path = path }, request_options);
}
pub const ListInternSecretsResponse = common.Response(SecretList);
pub fn listInternSecrets(client: anytype, id: []const u8, request: ListRequest, request_options: options_mod.RequestOptions) !ListInternSecretsResponse {
    return listInternSecretsWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, id, request, request_options);
}
pub fn listInternSecretsWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, id: []const u8, request: ListRequest, request_options: options_mod.RequestOptions) !ListInternSecretsResponse {
    const encoded_id = try common.segment(allocator, id);
    defer allocator.free(encoded_id);
    const path = try std.fmt.allocPrint(allocator, "/vault/interns/{s}/secrets", .{encoded_id});
    defer allocator.free(path);
    const query_string = try listQuery(allocator, request);
    defer allocator.free(query_string);
    return common.execute(ListInternSecretsResponse.Payload, allocator, config, transport, .{ .method = .GET, .path = path, .query = query_string }, request_options);
}
pub const ListEffectiveSecretsResponse = common.Response(EffectiveSecretList);
pub fn listEffectiveSecrets(client: anytype, id: []const u8, request: ListRequest, request_options: options_mod.RequestOptions) !ListEffectiveSecretsResponse {
    return listEffectiveSecretsWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, id, request, request_options);
}
pub fn listEffectiveSecretsWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, id: []const u8, request: ListRequest, request_options: options_mod.RequestOptions) !ListEffectiveSecretsResponse {
    const encoded_id = try common.segment(allocator, id);
    defer allocator.free(encoded_id);
    const path = try std.fmt.allocPrint(allocator, "/vault/interns/{s}/effective-secrets", .{encoded_id});
    defer allocator.free(path);
    const query_string = try listQuery(allocator, request);
    defer allocator.free(query_string);
    return common.execute(ListEffectiveSecretsResponse.Payload, allocator, config, transport, .{ .method = .GET, .path = path, .query = query_string }, request_options);
}
pub const PutInternSecretResponse = common.Response(struct { data: Secret });
pub fn putInternSecret(client: anytype, id: []const u8, name: []const u8, request: WriteRequest, request_options: options_mod.RequestOptions) !PutInternSecretResponse {
    return putInternSecretWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, id, name, request, request_options);
}
pub fn putInternSecretWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, id: []const u8, name: []const u8, request: WriteRequest, request_options: options_mod.RequestOptions) !PutInternSecretResponse {
    const encoded_id = try common.segment(allocator, id);
    defer allocator.free(encoded_id);
    const encoded_name = try common.segment(allocator, name);
    defer allocator.free(encoded_name);
    const path = try std.fmt.allocPrint(allocator, "/vault/interns/{s}/secrets/{s}", .{ encoded_id, encoded_name });
    defer allocator.free(path);
    const body = try json.stringifyRequest(allocator, request);
    defer allocator.free(body);
    return common.execute(PutInternSecretResponse.Payload, allocator, config, transport, .{ .method = .PUT, .path = path, .body = body }, request_options);
}
pub const DeleteInternSecretResponse = common.Response(void);
pub fn deleteInternSecret(client: anytype, id: []const u8, name: []const u8, request_options: options_mod.RequestOptions) !DeleteInternSecretResponse {
    return deleteInternSecretWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, id, name, request_options);
}
pub fn deleteInternSecretWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, id: []const u8, name: []const u8, request_options: options_mod.RequestOptions) !DeleteInternSecretResponse {
    const encoded_id = try common.segment(allocator, id);
    defer allocator.free(encoded_id);
    const encoded_name = try common.segment(allocator, name);
    defer allocator.free(encoded_name);
    const path = try std.fmt.allocPrint(allocator, "/vault/interns/{s}/secrets/{s}", .{ encoded_id, encoded_name });
    defer allocator.free(path);
    return common.execute(DeleteInternSecretResponse.Payload, allocator, config, transport, .{ .method = .DELETE, .path = path }, request_options);
}
pub const CopySecretsResponse = common.Response(struct { data: []Secret });
pub fn copySecrets(client: anytype, id: []const u8, request: CopyRequest, request_options: options_mod.RequestOptions) !CopySecretsResponse {
    return copySecretsWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, id, request, request_options);
}
pub fn copySecretsWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, id: []const u8, request: CopyRequest, request_options: options_mod.RequestOptions) !CopySecretsResponse {
    const encoded_id = try common.segment(allocator, id);
    defer allocator.free(encoded_id);
    const path = try std.fmt.allocPrint(allocator, "/vault/interns/{s}/secrets/copy", .{encoded_id});
    defer allocator.free(path);
    const body = try json.stringifyRequest(allocator, request);
    defer allocator.free(body);
    return common.execute(CopySecretsResponse.Payload, allocator, config, transport, .{ .method = .POST, .path = path, .body = body }, request_options);
}

test "listSecrets uses scoped escaped path and parses 200" {
    const Transport = struct {
        pub fn execute(_: @This(), allocator: std.mem.Allocator, prepared: http.PreparedRequest) !http.HttpResponse {
            try std.testing.expectEqual(std.http.Method.GET, prepared.method);
            try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/vault/secrets?limit=2&offset=3", prepared.url);
            try std.testing.expect(prepared.body == null);
            return (http.FakeTransport{ .status = @fromBackingInt(200), .body = "{\"data\":[{\"created_at\":\"2026-09-15T17:44:00.000Z\",\"fingerprint\":\"sha256:9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08\",\"hosts\":[\"api.github.com\"],\"name\":\"github_token\"},{\"created_at\":\"2026-08-01T09:30:00.000Z\",\"fingerprint\":null,\"hosts\":null,\"name\":\"legacy_token\"}],\"has_more\":false}", .headers = &.{.{ .name = "x-request-id", .value = "owned" }} }).execute(allocator, prepared);
        }
    };
    var result = try listSecretsWithTransport(std.testing.allocator, .{ .api_key = "test" }, Transport{}, .{ .limit = 2, .offset = 3 }, .{});
    defer result.deinit();
    try std.testing.expectEqualStrings("owned", result.response_metadata.request_id.?);
    try std.testing.expectError(error.ApiError, listSecretsWithTransport(std.testing.allocator, .{ .api_key = "test" }, http.FakeTransport{ .status = .forbidden }, .{ .limit = 2, .offset = 3 }, .{}));
}
test "putSecret uses scoped escaped path and parses 200" {
    const Transport = struct {
        pub fn execute(_: @This(), allocator: std.mem.Allocator, prepared: http.PreparedRequest) !http.HttpResponse {
            try std.testing.expectEqual(std.http.Method.PUT, prepared.method);
            try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/vault/secrets/a%2Fb", prepared.url);
            var parsed = try json.parseResponse(std.json.Value, allocator, prepared.body.?);
            defer parsed.deinit();
            try std.testing.expect(parsed.value.object.contains("value"));
            return (http.FakeTransport{ .status = @fromBackingInt(200), .body = "{\"data\":{\"created_at\":\"2026-09-15T17:44:00.000Z\",\"fingerprint\":\"sha256:9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08\",\"hosts\":[\"api.github.com\"],\"name\":\"github_token\"}}", .headers = &.{.{ .name = "x-request-id", .value = "owned" }} }).execute(allocator, prepared);
        }
    };
    var result = try putSecretWithTransport(std.testing.allocator, .{ .api_key = "test" }, Transport{}, "a/b", .{ .value = "secret", .hosts = &.{"api.example.com"} }, .{});
    defer result.deinit();
    try std.testing.expectEqualStrings("owned", result.response_metadata.request_id.?);
    try std.testing.expectError(error.ApiError, putSecretWithTransport(std.testing.allocator, .{ .api_key = "test" }, http.FakeTransport{ .status = .forbidden }, "a/b", .{ .value = "secret", .hosts = &.{"api.example.com"} }, .{}));
}
test "deleteSecret uses scoped escaped path and parses 204" {
    const Transport = struct {
        pub fn execute(_: @This(), allocator: std.mem.Allocator, prepared: http.PreparedRequest) !http.HttpResponse {
            try std.testing.expectEqual(std.http.Method.DELETE, prepared.method);
            try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/vault/secrets/a%2Fb", prepared.url);
            try std.testing.expect(prepared.body == null);
            return (http.FakeTransport{ .status = @fromBackingInt(204), .body = "", .headers = &.{.{ .name = "x-request-id", .value = "owned" }} }).execute(allocator, prepared);
        }
    };
    var result = try deleteSecretWithTransport(std.testing.allocator, .{ .api_key = "test" }, Transport{}, "a/b", .{});
    defer result.deinit();
    try std.testing.expectEqualStrings("owned", result.response_metadata.request_id.?);
    try std.testing.expectError(error.ApiError, deleteSecretWithTransport(std.testing.allocator, .{ .api_key = "test" }, http.FakeTransport{ .status = .forbidden }, "a/b", .{}));
}
test "listInternSecrets uses scoped escaped path and parses 200" {
    const Transport = struct {
        pub fn execute(_: @This(), allocator: std.mem.Allocator, prepared: http.PreparedRequest) !http.HttpResponse {
            try std.testing.expectEqual(std.http.Method.GET, prepared.method);
            try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/vault/interns/a%2Fb/secrets", prepared.url);
            try std.testing.expect(prepared.body == null);
            return (http.FakeTransport{ .status = @fromBackingInt(200), .body = "{\"data\":[{\"created_at\":\"2026-09-15T17:44:00.000Z\",\"fingerprint\":\"sha256:9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08\",\"hosts\":[\"api.github.com\"],\"name\":\"github_token\"},{\"created_at\":\"2026-08-01T09:30:00.000Z\",\"fingerprint\":null,\"hosts\":null,\"name\":\"legacy_token\"}],\"has_more\":false}", .headers = &.{.{ .name = "x-request-id", .value = "owned" }} }).execute(allocator, prepared);
        }
    };
    var result = try listInternSecretsWithTransport(std.testing.allocator, .{ .api_key = "test" }, Transport{}, "a/b", .{}, .{});
    defer result.deinit();
    try std.testing.expectEqualStrings("owned", result.response_metadata.request_id.?);
    try std.testing.expectError(error.ApiError, listInternSecretsWithTransport(std.testing.allocator, .{ .api_key = "test" }, http.FakeTransport{ .status = .forbidden }, "a/b", .{}, .{}));
}
test "listEffectiveSecrets uses scoped escaped path and parses 200" {
    const Transport = struct {
        pub fn execute(_: @This(), allocator: std.mem.Allocator, prepared: http.PreparedRequest) !http.HttpResponse {
            try std.testing.expectEqual(std.http.Method.GET, prepared.method);
            try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/vault/interns/a%2Fb/effective-secrets", prepared.url);
            try std.testing.expect(prepared.body == null);
            return (http.FakeTransport{ .status = @fromBackingInt(200), .body = "{\"data\":[{\"created_at\":\"2026-09-15T17:44:00.000Z\",\"fingerprint\":\"sha256:9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08\",\"hosts\":[\"api.github.com\"],\"name\":\"github_token\",\"scope\":\"intern\"},{\"created_at\":\"2026-09-15T17:44:00.000Z\",\"fingerprint\":\"sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\",\"hosts\":[\"api.linear.app\"],\"name\":\"linear_api_key\",\"scope\":\"workspace\"},{\"created_at\":\"2026-08-01T09:30:00.000Z\",\"fingerprint\":null,\"hosts\":null,\"name\":\"legacy_token\",\"scope\":\"workspace\"}],\"has_more\":false}", .headers = &.{.{ .name = "x-request-id", .value = "owned" }} }).execute(allocator, prepared);
        }
    };
    var result = try listEffectiveSecretsWithTransport(std.testing.allocator, .{ .api_key = "test" }, Transport{}, "a/b", .{}, .{});
    defer result.deinit();
    try std.testing.expectEqualStrings("owned", result.response_metadata.request_id.?);
    try std.testing.expectError(error.ApiError, listEffectiveSecretsWithTransport(std.testing.allocator, .{ .api_key = "test" }, http.FakeTransport{ .status = .forbidden }, "a/b", .{}, .{}));
}
test "putInternSecret uses scoped escaped path and parses 200" {
    const Transport = struct {
        pub fn execute(_: @This(), allocator: std.mem.Allocator, prepared: http.PreparedRequest) !http.HttpResponse {
            try std.testing.expectEqual(std.http.Method.PUT, prepared.method);
            try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/vault/interns/a%2Fb/secrets/c%3Fd", prepared.url);
            var parsed = try json.parseResponse(std.json.Value, allocator, prepared.body.?);
            defer parsed.deinit();
            try std.testing.expect(parsed.value.object.contains("hosts"));
            return (http.FakeTransport{ .status = @fromBackingInt(200), .body = "{\"data\":{\"created_at\":\"2026-09-15T17:44:00.000Z\",\"fingerprint\":\"sha256:9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08\",\"hosts\":[\"api.github.com\"],\"name\":\"github_token\"}}", .headers = &.{.{ .name = "x-request-id", .value = "owned" }} }).execute(allocator, prepared);
        }
    };
    var result = try putInternSecretWithTransport(std.testing.allocator, .{ .api_key = "test" }, Transport{}, "a/b", "c?d", .{ .value = "secret", .hosts = &.{"api.example.com"} }, .{});
    defer result.deinit();
    try std.testing.expectEqualStrings("owned", result.response_metadata.request_id.?);
    try std.testing.expectError(error.ApiError, putInternSecretWithTransport(std.testing.allocator, .{ .api_key = "test" }, http.FakeTransport{ .status = .forbidden }, "a/b", "c?d", .{ .value = "secret", .hosts = &.{"api.example.com"} }, .{}));
}
test "deleteInternSecret uses scoped escaped path and parses 204" {
    const Transport = struct {
        pub fn execute(_: @This(), allocator: std.mem.Allocator, prepared: http.PreparedRequest) !http.HttpResponse {
            try std.testing.expectEqual(std.http.Method.DELETE, prepared.method);
            try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/vault/interns/a%2Fb/secrets/c%3Fd", prepared.url);
            try std.testing.expect(prepared.body == null);
            return (http.FakeTransport{ .status = @fromBackingInt(204), .body = "", .headers = &.{.{ .name = "x-request-id", .value = "owned" }} }).execute(allocator, prepared);
        }
    };
    var result = try deleteInternSecretWithTransport(std.testing.allocator, .{ .api_key = "test" }, Transport{}, "a/b", "c?d", .{});
    defer result.deinit();
    try std.testing.expectEqualStrings("owned", result.response_metadata.request_id.?);
    try std.testing.expectError(error.ApiError, deleteInternSecretWithTransport(std.testing.allocator, .{ .api_key = "test" }, http.FakeTransport{ .status = .forbidden }, "a/b", "c?d", .{}));
}
test "copySecrets uses scoped escaped path and parses 200" {
    const Transport = struct {
        pub fn execute(_: @This(), allocator: std.mem.Allocator, prepared: http.PreparedRequest) !http.HttpResponse {
            try std.testing.expectEqual(std.http.Method.POST, prepared.method);
            try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/vault/interns/a%2Fb/secrets/copy", prepared.url);
            var parsed = try json.parseResponse(std.json.Value, allocator, prepared.body.?);
            defer parsed.deinit();
            try std.testing.expect(parsed.value.object.contains("names"));
            return (http.FakeTransport{ .status = @fromBackingInt(200), .body = "{\"data\":[{\"created_at\":\"2026-09-15T17:44:00.000Z\",\"fingerprint\":\"sha256:9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08\",\"hosts\":[\"api.github.com\"],\"name\":\"github_token\"}]}", .headers = &.{.{ .name = "x-request-id", .value = "owned" }} }).execute(allocator, prepared);
        }
    };
    var result = try copySecretsWithTransport(std.testing.allocator, .{ .api_key = "test" }, Transport{}, "a/b", .{ .names = &.{"github_token"} }, .{});
    defer result.deinit();
    try std.testing.expectEqualStrings("owned", result.response_metadata.request_id.?);
    try std.testing.expectError(error.ApiError, copySecretsWithTransport(std.testing.allocator, .{ .api_key = "test" }, http.FakeTransport{ .status = .forbidden }, "a/b", .{ .names = &.{"github_token"} }, .{}));
}

test "vault legacy metadata and future scopes remain readable without secret values" {
    var result = try listEffectiveSecretsWithTransport(std.testing.allocator, .{ .api_key = "test" }, http.FakeTransport{ .body = "{\"data\":[{\"name\":\"legacy\",\"hosts\":null,\"fingerprint\":null,\"created_at\":\"date\",\"scope\":\"future\"}],\"has_more\":true}" }, "intern", .{}, .{});
    defer result.deinit();
    try std.testing.expect(result.value.data[0].hosts == null);
    try std.testing.expect(result.value.data[0].fingerprint == null);
    try std.testing.expectEqualStrings("future", result.value.data[0].scope);
    try std.testing.expect(result.value.has_more);
    try std.testing.expectError(error.ApiError, copySecretsWithTransport(std.testing.allocator, .{ .api_key = "test" }, http.FakeTransport{ .status = .conflict }, "intern", .{ .names = &.{"legacy"} }, .{}));
    try std.testing.expectError(error.ApiError, putSecretWithTransport(std.testing.allocator, .{ .api_key = "test" }, http.FakeTransport{ .status = .service_unavailable }, "secret", .{ .value = "value", .hosts = &.{"example.com"} }, .{}));
}
