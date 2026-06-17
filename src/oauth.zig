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
    const bytes = [_]u8{0xab} ** default_verifier_random_bytes;
    const verifier = try createCodeVerifier(std.testing.allocator, &bytes);
    defer std.testing.allocator.free(verifier);

    try std.testing.expectEqual(@as(usize, 43), verifier.len);
    try std.testing.expect(std.mem.indexOfScalar(u8, verifier, '=') == null);
    try std.testing.expect(std.mem.indexOfScalar(u8, verifier, '+') == null);
    try std.testing.expect(std.mem.indexOfScalar(u8, verifier, '/') == null);
}

test "OAuth PKCE verifier rejects entropy lengths outside PKCE bounds" {
    const too_short = [_]u8{0xab} ** 31;
    const too_long = [_]u8{0xab} ** 97;

    try std.testing.expectError(error.InvalidCodeVerifierEntropy, createCodeVerifier(std.testing.allocator, &too_short));
    try std.testing.expectError(error.InvalidCodeVerifierEntropy, createCodeVerifier(std.testing.allocator, &too_long));
}
