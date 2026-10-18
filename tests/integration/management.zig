const std = @import("std");
const openrouter = @import("openrouter");
const support = @import("support.zig");

test "credits integration with management key" {
    try support.requireProfile(.management);
    var threaded: std.Io.Threaded = .init_single_threaded;
    defer threaded.deinit();

    var client = try support.initManagementClient(&threaded);
    defer client.deinit();

    var response = try client.credits.get(.{});
    defer response.deinit();

    try std.testing.expect(response.data.total_credits >= 0);
}

test "BYOK list integration with management key" {
    try support.requireProfile(.management);
    var threaded: std.Io.Threaded = .init_single_threaded;
    defer threaded.deinit();

    var client = try support.initManagementClient(&threaded);
    defer client.deinit();

    var response = try client.byok.list(.{ .limit = 10 }, .{});
    defer response.deinit();

    try std.testing.expect(response.data.len == 0 or response.data[0].id != null);
}

test "guardrails list integration with management key" {
    try support.requireProfile(.management);
    var threaded: std.Io.Threaded = .init_single_threaded;
    defer threaded.deinit();

    var client = try support.initManagementClient(&threaded);
    defer client.deinit();

    var response = try client.guardrails.list(.{ .limit = 10 }, .{});
    defer response.deinit();

    try std.testing.expect(response.data.len == 0 or response.data[0].id != null);
}

test "workspaces list integration with management key" {
    try support.requireProfile(.management);
    var threaded: std.Io.Threaded = .init_single_threaded;
    defer threaded.deinit();

    var client = try support.initManagementClient(&threaded);
    defer client.deinit();

    var response = try client.workspaces.list(.{ .limit = 10 }, .{});
    defer response.deinit();

    try std.testing.expect(response.data.len == 0 or response.data[0].id != null);
}

test "observability destinations list integration with management key" {
    try support.requireProfile(.management);
    var threaded: std.Io.Threaded = .init_single_threaded;
    defer threaded.deinit();

    var client = try support.initManagementClient(&threaded);
    defer client.deinit();

    var response = try client.observability.destinations.list(.{ .limit = 10 }, .{});
    defer response.deinit();

    try std.testing.expect(response.data.len == 0 or response.data[0].id != null);
}

test "organization members list integration with management key" {
    try support.requireProfile(.management);
    var threaded: std.Io.Threaded = .init_single_threaded;
    defer threaded.deinit();

    var client = try support.initManagementClient(&threaded);
    defer client.deinit();

    var response = try client.organization.members.list(.{ .limit = 10 }, .{});
    defer response.deinit();

    try std.testing.expect(response.data.len == 0 or response.data[0].id != null);
}

test "activity integration with management key" {
    try support.requireProfile(.management);
    var threaded: std.Io.Threaded = .init_single_threaded;
    defer threaded.deinit();

    var client = try support.initManagementClient(&threaded);
    defer client.deinit();

    var response = try client.activity.get(.{}, .{});
    defer response.deinit();

    if (response.data.len > 0) {
        try std.testing.expect(response.data[0].date.len > 0);
        try std.testing.expect(response.data[0].model.len > 0);
    }
}

test "management credential identity integration" {
    try support.requireProfile(.management);
    var threaded: std.Io.Threaded = .init_single_threaded;
    defer threaded.deinit();
    var client = try support.initManagementClient(&threaded);
    defer client.deinit();
    var response = try client.key.get(.{});
    defer response.deinit();
    try std.testing.expect(response.data.is_management_key);
}

test "management API key listing integration" {
    try support.requireProfile(.management);
    var threaded: std.Io.Threaded = .init_single_threaded;
    defer threaded.deinit();
    var client = try support.initManagementClient(&threaded);
    defer client.deinit();
    var response = try client.keys.list(.{}, .{});
    defer response.deinit();
    if (response.data.len > 0) try std.testing.expect(response.data[0].hash != null and response.data[0].hash.?.len > 0);
}

test "organization settings read integration" {
    try support.requireProfile(.management);
    var threaded: std.Io.Threaded = .init_single_threaded;
    defer threaded.deinit();
    var client = try support.initManagementClient(&threaded);
    defer client.deinit();
    var response = try client.organization.settings.get(.{});
    defer response.deinit();
    try std.testing.expect(response.data.id.len > 0);
}

test "SCIM group discovery integration" {
    try support.requireProfile(.management);
    var threaded: std.Io.Threaded = .init_single_threaded;
    defer threaded.deinit();
    var client = try support.initManagementClient(&threaded);
    defer client.deinit();
    var response = try client.scim.listGroups(.{ .limit = 2 }, .{});
    defer response.deinit();
    try std.testing.expect(response.total_count >= response.data.len);
}

test "SCIM mapping discovery integration" {
    try support.requireProfile(.management);
    var threaded: std.Io.Threaded = .init_single_threaded;
    defer threaded.deinit();
    var client = try support.initManagementClient(&threaded);
    defer client.deinit();
    var response = try client.scim.listMappings(.{ .limit = 2 }, .{});
    defer response.deinit();
    try std.testing.expect(response.total_count >= response.data.len);
}

test "private endpoint discovery integration" {
    try support.requireProfile(.management);
    var threaded: std.Io.Threaded = .init_single_threaded;
    defer threaded.deinit();
    var client = try support.initManagementClient(&threaded);
    defer client.deinit();
    var response = try client.private_endpoints.list(.{});
    defer response.deinit();
    for (response.data) |endpoint| {
        try std.testing.expect(endpoint.id.len > 0);
        try std.testing.expect(endpoint.status.len > 0);
    }
}
