//! OAuth PKCE helpers.

const std = @import("std");

pub const code_challenge_method_s256 = "S256";
pub const default_verifier_random_bytes: usize = 32;
pub const min_verifier_len: usize = 43;
pub const max_verifier_len: usize = 128;

pub const Error = error{
    InvalidCodeVerifierEntropy,
};

pub fn createCodeVerifier(allocator: std.mem.Allocator, random_bytes: []const u8) (Error || std.mem.Allocator.Error)![]u8 {
    const verifier_len = std.base64.url_safe_no_pad.Encoder.calcSize(random_bytes.len);
    if (verifier_len < min_verifier_len or verifier_len > max_verifier_len) return error.InvalidCodeVerifierEntropy;
    return base64UrlNoPadAlloc(allocator, random_bytes);
}

pub fn createS256CodeChallenge(allocator: std.mem.Allocator, code_verifier: []const u8) ![]u8 {
    var digest: [std.crypto.hash.sha2.Sha256.digest_length]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(code_verifier, &digest, .{});
    return base64UrlNoPadAlloc(allocator, &digest);
}

fn base64UrlNoPadAlloc(allocator: std.mem.Allocator, bytes: []const u8) ![]u8 {
    const size = std.base64.url_safe_no_pad.Encoder.calcSize(bytes.len);
    const encoded = try allocator.alloc(u8, size);
    errdefer allocator.free(encoded);
    const result = std.base64.url_safe_no_pad.Encoder.encode(encoded, bytes);
    std.debug.assert(result.len == encoded.len);
    return encoded;
}

test "OAuth PKCE S256 challenge matches RFC 7636 example" {
    const verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk";

    const challenge = try createS256CodeChallenge(std.testing.allocator, verifier);
    defer std.testing.allocator.free(challenge);

    try std.testing.expectEqualStrings("E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM", challenge);
}

test "OAuth PKCE verifier uses base64url without padding" {
    const bytes: [default_verifier_random_bytes]u8 = @splat(0xab);
    const verifier = try createCodeVerifier(std.testing.allocator, &bytes);
    defer std.testing.allocator.free(verifier);

    try std.testing.expectEqual(@as(usize, 43), verifier.len);
    try std.testing.expect(std.mem.indexOfScalar(u8, verifier, '=') == null);
    try std.testing.expect(std.mem.indexOfScalar(u8, verifier, '+') == null);
    try std.testing.expect(std.mem.indexOfScalar(u8, verifier, '/') == null);
}

test "OAuth PKCE verifier rejects entropy lengths outside PKCE bounds" {
    const too_short: [31]u8 = @splat(0xab);
    const too_long: [97]u8 = @splat(0xab);

    try std.testing.expectError(error.InvalidCodeVerifierEntropy, createCodeVerifier(std.testing.allocator, &too_short));
    try std.testing.expectError(error.InvalidCodeVerifierEntropy, createCodeVerifier(std.testing.allocator, &too_long));
}

const common = @import("enterprise.zig");
const config_mod = @import("config.zig");
const http = @import("http.zig");
const options_mod = @import("options.zig");
const query = @import("query.zig");

pub const SigningKey = struct { kty: []const u8, crv: []const u8, kid: []const u8, x: []const u8, y: []const u8, alg: []const u8, use: []const u8 };
pub const JwksResponse = common.Response(struct { keys: []SigningKey });
pub const TokenExchangeRequest = struct {
    subject_token: []const u8,
    federation_policy_id: []const u8,
    scope: ?[]const u8 = null,
    requested_token_type: ?[]const u8 = null,
};
pub const Token = struct { access_token: []const u8, issued_token_type: []const u8, token_type: []const u8, expires_in: u64, scope: []const u8 };
pub const TokenExchangeResponse = common.Response(Token);

/// Returns public signing keys; does not verify JWT signatures or claims.
pub fn jwks(client: anytype, request_options: options_mod.RequestOptions) !JwksResponse {
    return jwksWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, request_options);
}
pub fn jwksWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, request_options: options_mod.RequestOptions) !JwksResponse {
    return common.execute(JwksResponse.Payload, allocator, config, transport, .{ .method = .GET, .path = "/oauth/jwks", .authenticated = false }, request_options);
}

/// RFC 8693 exchange for an organization federation policy, independent of the
/// authorization-code API-key flow. The subject token is the sole credential.
pub fn exchangeToken(client: anytype, request: TokenExchangeRequest, request_options: options_mod.RequestOptions) !TokenExchangeResponse {
    return exchangeTokenWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, request, request_options);
}
pub fn exchangeTokenWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, request: TokenExchangeRequest, request_options: options_mod.RequestOptions) !TokenExchangeResponse {
    const body = try query.build(allocator, &.{
        .{ .name = "grant_type", .value = "urn:ietf:params:oauth:grant-type:token-exchange" },
        .{ .name = "subject_token_type", .value = "urn:ietf:params:oauth:token-type:jwt" },
        .{ .name = "subject_token", .value = request.subject_token },
        .{ .name = "federation_policy_id", .value = request.federation_policy_id },
        .{ .name = "scope", .value = request.scope },
        .{ .name = "requested_token_type", .value = request.requested_token_type },
    });
    defer allocator.free(body);
    return common.execute(Token, allocator, config, transport, .{
        .method = .POST,
        .path = "/oauth/token",
        .authenticated = false,
        .content_type = "application/x-www-form-urlencoded",
        .body = body,
    }, request_options);
}

test "token exchange uses form encoding and does not send the client key" {
    const Transport = struct {
        pub fn execute(_: @This(), allocator: std.mem.Allocator, prepared: http.PreparedRequest) !http.HttpResponse {
            try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/oauth/token", prepared.url);
            try std.testing.expectEqualStrings("grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Atoken-exchange&subject_token_type=urn%3Aietf%3Aparams%3Aoauth%3Atoken-type%3Ajwt&subject_token=a%2Bb%26c%3D&federation_policy_id=policy&scope=management", prepared.body.?);
            var content_type = false;
            for (prepared.headers) |h| {
                try std.testing.expect(!std.ascii.eqlIgnoreCase(h.name, "Authorization"));
                if (std.ascii.eqlIgnoreCase(h.name, "Content-Type")) {
                    try std.testing.expectEqualStrings("application/x-www-form-urlencoded", h.value);
                    content_type = true;
                }
            }
            try std.testing.expect(content_type);
            return (http.FakeTransport{ .body = "{\"access_token\":\"temporary\",\"issued_token_type\":\"urn:ietf:params:oauth:token-type:access_token\",\"token_type\":\"Bearer\",\"expires_in\":900,\"scope\":\"management\"}" }).execute(allocator, prepared);
        }
    };
    var result = try exchangeTokenWithTransport(std.testing.allocator, .{ .api_key = "must-not-send" }, Transport{}, .{ .subject_token = "a+b&c=", .federation_policy_id = "policy", .scope = "management" }, .{});
    defer result.deinit();
    try std.testing.expectEqualStrings("temporary", result.value.access_token);
    try std.testing.expectEqual(@as(u64, 900), result.value.expires_in);
    try std.testing.expectError(error.ApiError, exchangeTokenWithTransport(std.testing.allocator, .{ .api_key = "test" }, http.FakeTransport{ .status = .unauthorized }, .{ .subject_token = "jwt", .federation_policy_id = "policy" }, .{}));
}

test "JWKS is public and owns key material" {
    const Transport = struct {
        pub fn execute(_: @This(), allocator: std.mem.Allocator, prepared: http.PreparedRequest) !http.HttpResponse {
            try std.testing.expectEqual(std.http.Method.GET, prepared.method);
            try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/oauth/jwks", prepared.url);
            for (prepared.headers) |h| try std.testing.expect(!std.ascii.eqlIgnoreCase(h.name, "Authorization"));
            return (http.FakeTransport{ .body = "{\"keys\":[{\"kty\":\"EC\",\"crv\":\"P-256\",\"kid\":\"signing-key\",\"x\":\"x\",\"y\":\"y\",\"alg\":\"ES256\",\"use\":\"sig\"}]}" }).execute(allocator, prepared);
        }
    };
    var result = try jwksWithTransport(std.testing.allocator, .{ .api_key = "must-not-send" }, Transport{}, .{});
    defer result.deinit();
    try std.testing.expectEqualStrings("signing-key", result.value.keys[0].kid);
}
