const std = @import("std");
const openrouter = @import("openrouter");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    const api_key = init.minimal.environ.getAlloc(allocator, "OPENROUTER_API_KEY") catch null orelse {
        std.debug.print("Set OPENROUTER_API_KEY to run this example.\n", .{});
        return;
    };
    defer allocator.free(api_key);

    const callback_url = init.minimal.environ.getAlloc(allocator, "OPENROUTER_AUTH_CALLBACK_URL") catch null orelse {
        std.debug.print("Set OPENROUTER_AUTH_CALLBACK_URL to create an auth-key code.\n", .{});
        return;
    };
    defer allocator.free(callback_url);

    const code_challenge = init.minimal.environ.getAlloc(allocator, "OPENROUTER_AUTH_CODE_CHALLENGE") catch null orelse {
        std.debug.print("Set OPENROUTER_AUTH_CODE_CHALLENGE to create an auth-key code.\n", .{});
        return;
    };
    defer allocator.free(code_challenge);

    const method_env = init.minimal.environ.getAlloc(allocator, "OPENROUTER_AUTH_CODE_CHALLENGE_METHOD") catch null;
    defer if (method_env) |value| allocator.free(value);
    const code_challenge_method = method_env orelse "S256";

    var client = try openrouter.Client.init(allocator, init.io, .{
        .api_key = api_key,
    });
    defer client.deinit();

    var created = try client.oauth.createAuthCode(.{
        .callback_url = callback_url,
        .code_challenge = code_challenge,
        .code_challenge_method = code_challenge_method,
    }, .{});
    defer created.deinit();

    std.debug.print("Created auth-key code id: {s}\n", .{created.data.id});
    std.debug.print("Created at: {s}\n", .{created.data.created_at});

    const auth_code = init.minimal.environ.getAlloc(allocator, "OPENROUTER_AUTH_CODE") catch null;
    defer if (auth_code) |value| allocator.free(value);
    const code_verifier = init.minimal.environ.getAlloc(allocator, "OPENROUTER_AUTH_CODE_VERIFIER") catch null;
    defer if (code_verifier) |value| allocator.free(value);

    if (auth_code == null or code_verifier == null) {
        std.debug.print("Set OPENROUTER_AUTH_CODE and OPENROUTER_AUTH_CODE_VERIFIER to exchange a returned code.\n", .{});
        return;
    }

    var exchanged = try client.oauth.exchangeAuthCodeForAPIKey(.{
        .code = auth_code.?,
        .code_challenge_method = code_challenge_method,
        .code_verifier = code_verifier.?,
    }, .{});
    defer exchanged.deinit();

    std.debug.print("Exchanged key for user: {s}\n", .{exchanged.user_id});
    std.debug.print("Returned API key length: {d}\n", .{exchanged.key.len});
}
