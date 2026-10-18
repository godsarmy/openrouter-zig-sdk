//! Private endpoint lifecycle management. Requires a management key and private-endpoint entitlement.
const std = @import("std");
const common = @import("enterprise.zig");
const config_mod = @import("config.zig");
const errors = @import("errors.zig");
const http = @import("http.zig");
const json = @import("json.zig");
const options_mod = @import("options.zig");

pub const Summary = struct {
    id: []const u8,
    /// Preserved as a string to allow future server lifecycle states.
    status: []const u8,
    model_permaslug: []const u8,
    model_slug: ?[]const u8,
    model_name: ?[]const u8,
    provider_name: []const u8,
    created_at: []const u8,
};

pub const Pricing = struct {
    /// USD per token, preserved as decimal strings.
    prompt: []const u8,
    completion: []const u8,
};

pub const Endpoint = struct {
    id: []const u8,
    status: []const u8,
    model_permaslug: []const u8,
    model_slug: ?[]const u8,
    model_name: ?[]const u8,
    provider_name: []const u8,
    provider_slug: ?[]const u8,
    base_url: ?[]const u8,
    upstream_model_id: []const u8,
    declared_zdr: ?bool,
    /// Known values are global, europe, and us; preserves future values.
    declared_region: ?[]const u8,
    pricing: Pricing,
};

pub const Activation = struct { workspace_id: []const u8 };
pub const CreateRequest = struct {
    model_permaslug: []const u8,
    provider_slug: []const u8,
    upstream_model_id: []const u8,
    base_url: ?[]const u8 = null,
    declared_region: ?[]const u8 = null,
    declared_zdr: ?bool = null,
    pricing: ?Pricing = null,
    activate: ?Activation = null,
};
pub const NullableString = common.Nullable([]const u8);
pub const NullableBool = common.Nullable(bool);
/// Draft edits invalidate previous validation; active endpoints cannot be edited.
pub const UpdateRequest = struct {
    upstream_model_id: []const u8,
    base_url: ?[]const u8 = null,
    declared_region: ?NullableString = null,
    declared_zdr: ?NullableBool = null,
};
pub const UpdatePricingRequest = struct { pricing: Pricing };
pub const ValidateRequest = Activation;
pub const ManagedEndpoint = struct {
    id: []const u8,
    status: []const u8,
    model_permaslug: []const u8,
    model_slug: ?[]const u8,
    model_name: ?[]const u8,
    provider_name: []const u8,
    created_at: []const u8,
    declared_zdr: ?bool,
    declared_region: ?[]const u8,
};
pub const Check = struct {
    name: []const u8,
    passed: bool,
    actual_model: ?[]const u8 = null,
    reason: ?[]const u8 = null,
    upstream_message: ?[]const u8 = null,
    upstream_status: ?u16 = null,
};
pub const Validation = struct { passed: bool, checks: []Check };
pub const ManagedResponse = OwnedResponse(ManagedEndpoint);
pub const ValidationResponse = OwnedResponse(Validation);
const Deleted = struct { id: []const u8 };
pub const DeleteResponse = OwnedResponse(Deleted);
pub const Failure = struct { code: i64, message: []const u8 };
/// An HTTP failure can still contain a created draft. Check `failure` before
/// treating this as success. All fields and metadata live until `deinit`.
pub const CreateResponse = struct {
    arena: std.heap.ArenaAllocator,
    status: std.http.Status,
    endpoint: ?ManagedEndpoint,
    validation: ?Validation,
    failure: ?Failure,
    response_metadata: http.ResponseMetadata,
    pub fn deinit(self: *@This()) void {
        self.arena.deinit();
        self.* = undefined;
    }
};

pub const ListResponse = OwnedResponse([]Summary);
pub const GetResponse = OwnedResponse(Endpoint);

fn OwnedResponse(comptime T: type) type {
    return struct {
        /// All data and metadata are owned until `deinit`.
        arena: std.heap.ArenaAllocator,
        data: T,
        response_metadata: http.ResponseMetadata,

        pub fn deinit(self: *@This()) void {
            self.arena.deinit();
            self.* = undefined;
        }
    };
}

pub fn list(client: anytype, request_options: options_mod.RequestOptions) !ListResponse {
    return listWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, request_options);
}

pub fn listWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, request_options: options_mod.RequestOptions) !ListResponse {
    return read([]Summary, allocator, config, transport, "/private-endpoints", request_options);
}

pub fn get(client: anytype, id: []const u8, request_options: options_mod.RequestOptions) !GetResponse {
    return getWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, id, request_options);
}

pub fn getWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, id: []const u8, request_options: options_mod.RequestOptions) !GetResponse {
    const path = try endpointPath(allocator, id);
    defer allocator.free(path);
    return read(Endpoint, allocator, config, transport, path, request_options);
}

fn endpointPath(allocator: std.mem.Allocator, id: []const u8) ![]u8 {
    const encoded = try common.segment(allocator, id);
    defer allocator.free(encoded);
    return std.fmt.allocPrint(allocator, "/private-endpoints/{s}", .{encoded});
}

fn read(comptime T: type, allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, path: []const u8, request_options: options_mod.RequestOptions) !OwnedResponse(T) {
    return execute(T, allocator, config, transport, .{ .method = .GET, .path = path }, request_options);
}

fn execute(comptime T: type, allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, request: http.HttpRequest, request_options: options_mod.RequestOptions) !OwnedResponse(T) {
    var prepared = try http.prepareRequest(allocator, config, request, request_options);
    defer prepared.deinit();
    var response = try transport.execute(allocator, prepared);
    defer response.deinit();
    if (errors.isErrorStatus(@backingInt(response.status))) return error.ApiError;
    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const parsed = try json.parseResponseLeaky(struct { data: T }, arena.allocator(), try arena.allocator().dupe(u8, response.body));
    const metadata = try http.ResponseMetadata.fromHttpResponse(arena.allocator(), response);
    return .{ .arena = arena, .data = parsed.data, .response_metadata = metadata };
}

test "private endpoint detail escapes identifiers and preserves response data" {
    const Transport = struct {
        pub fn execute(_: @This(), allocator: std.mem.Allocator, prepared: http.PreparedRequest) !http.HttpResponse {
            try std.testing.expectEqual(std.http.Method.GET, prepared.method);
            try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/private-endpoints/a%2Fb%3Fc%23d", prepared.url);
            try std.testing.expect(prepared.body == null);
            return (http.FakeTransport{ .body = "{\"data\":{\"base_url\":\"https://contoso.openai.azure.com\",\"declared_region\":\"us\",\"declared_zdr\":true,\"id\":\"5b1c4c4e-7d0a-4a8e-9f3a-2d6c1b0e8a11\",\"model_name\":\"OpenAI: GPT-4o\",\"model_permaslug\":\"openai/gpt-4o-2024-08-06\",\"model_slug\":\"openai/gpt-4o\",\"pricing\":{\"completion\":\"0.00001\",\"prompt\":\"0.0000025\"},\"provider_name\":\"Azure\",\"provider_slug\":\"azure\",\"status\":\"active\",\"upstream_model_id\":\"gpt-4o-prod\"}}", .headers = &.{.{ .name = "x-request-id", .value = "req_private" }} }).execute(allocator, prepared);
        }
    };
    var result = try getWithTransport(std.testing.allocator, .{ .api_key = "test" }, Transport{}, "a/b?c#d", .{});
    defer result.deinit();
    try std.testing.expectEqualStrings("0.0000025", result.data.pricing.prompt);
    try std.testing.expectEqualStrings("us", result.data.declared_region.?);
    try std.testing.expect(result.data.declared_zdr.?);
    try std.testing.expectEqualStrings("req_private", result.response_metadata.request_id.?);
}

test "private endpoint list preserves future states and unlisted models" {
    const Transport = struct {
        pub fn execute(_: @This(), allocator: std.mem.Allocator, prepared: http.PreparedRequest) !http.HttpResponse {
            try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/private-endpoints", prepared.url);
            return (http.FakeTransport{ .body = "{\"data\":[{\"id\":\"ep_1\",\"status\":\"future\",\"model_permaslug\":\"vendor/model\",\"model_slug\":null,\"model_name\":null,\"provider_name\":\"Provider\",\"created_at\":\"2026-10-17T00:00:00Z\",\"extra\":true}]}" }).execute(allocator, prepared);
        }
    };
    var result = try listWithTransport(std.testing.allocator, .{ .api_key = "test" }, Transport{}, .{});
    defer result.deinit();
    try std.testing.expectEqual(@as(usize, 1), result.data.len);
    try std.testing.expectEqualStrings("future", result.data[0].status);
    try std.testing.expect(result.data[0].model_slug == null);
}

test "private endpoint reads reject invalid shapes and map access errors" {
    const config: config_mod.Config = .{ .api_key = "test" };
    var empty = try listWithTransport(std.testing.allocator, config, http.FakeTransport{ .body = "{\"data\":[]}" }, .{});
    defer empty.deinit();
    try std.testing.expectEqual(@as(usize, 0), empty.data.len);
    try std.testing.expectError(error.MissingField, getWithTransport(std.testing.allocator, config, http.FakeTransport{ .body = "{\"data\":{}}" }, "ep_1", .{}));
    try std.testing.expectError(error.ApiError, listWithTransport(std.testing.allocator, config, http.FakeTransport{ .status = .forbidden }, .{}));
    try std.testing.expectError(error.ApiError, getWithTransport(std.testing.allocator, config, http.FakeTransport{ .status = .not_found }, "ep_1", .{}));
    for ([_][]const u8{ "", ".", ".." }) |id| {
        try std.testing.expectError(error.InvalidPath, getWithTransport(std.testing.allocator, config, http.FakeTransport{}, id, .{}));
    }
}

fn mutate(comptime T: type, allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, method: std.http.Method, id: []const u8, suffix: []const u8, body: ?[]const u8, request_options: options_mod.RequestOptions) !OwnedResponse(T) {
    const base = try endpointPath(allocator, id);
    defer allocator.free(base);
    const path = try std.fmt.allocPrint(allocator, "{s}{s}", .{ base, suffix });
    defer allocator.free(path);
    return execute(T, allocator, config, transport, .{ .method = method, .path = path, .body = body }, request_options);
}

/// Supply an Idempotency-Key through request_options.extra_headers when retrying creation.
pub fn create(client: anytype, request: CreateRequest, request_options: options_mod.RequestOptions) !CreateResponse {
    return createWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, request, request_options);
}
pub fn createWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, request: CreateRequest, request_options: options_mod.RequestOptions) !CreateResponse {
    const body = try json.stringifyRequest(allocator, request);
    defer allocator.free(body);
    var prepared = try http.prepareRequest(allocator, config, .{ .method = .POST, .path = "/private-endpoints", .body = body }, request_options);
    defer prepared.deinit();
    var response = try transport.execute(allocator, prepared);
    defer response.deinit();
    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const a = arena.allocator();
    const text = try a.dupe(u8, response.body);
    var endpoint: ?ManagedEndpoint = null;
    var validation: ?Validation = null;
    var failure: ?Failure = null;
    if (errors.isErrorStatus(@backingInt(response.status))) {
        const parsed = try json.parseResponseLeaky(struct {
            @"error": Failure,
            data: ?struct { endpoint: ManagedEndpoint, validation: ?Validation } = null,
        }, a, text);
        failure = parsed.@"error";
        if (parsed.data) |data| {
            endpoint = data.endpoint;
            validation = data.validation;
        }
    } else {
        const parsed = try json.parseResponseLeaky(struct { data: ManagedEndpoint }, a, text);
        endpoint = parsed.data;
    }
    const metadata = try http.ResponseMetadata.fromHttpResponse(a, response);
    return .{ .arena = arena, .status = response.status, .endpoint = endpoint, .validation = validation, .failure = failure, .response_metadata = metadata };
}

pub fn update(client: anytype, id: []const u8, request: UpdateRequest, request_options: options_mod.RequestOptions) !GetResponse {
    return updateWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, id, request, request_options);
}
pub fn updateWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, id: []const u8, request: UpdateRequest, request_options: options_mod.RequestOptions) !GetResponse {
    const body = try json.stringifyRequest(allocator, request);
    defer allocator.free(body);
    return mutate(Endpoint, allocator, config, transport, .PATCH, id, "", body, request_options);
}
pub fn delete(client: anytype, id: []const u8, request_options: options_mod.RequestOptions) !DeleteResponse {
    return deleteWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, id, request_options);
}
pub fn deleteWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, id: []const u8, request_options: options_mod.RequestOptions) !DeleteResponse {
    return mutate(Deleted, allocator, config, transport, .DELETE, id, "", null, request_options);
}
pub fn activate(client: anytype, id: []const u8, request_options: options_mod.RequestOptions) !ManagedResponse {
    return activateWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, id, request_options);
}
pub fn activateWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, id: []const u8, request_options: options_mod.RequestOptions) !ManagedResponse {
    return mutate(ManagedEndpoint, allocator, config, transport, .POST, id, "/activate", null, request_options);
}
pub fn disable(client: anytype, id: []const u8, request_options: options_mod.RequestOptions) !ManagedResponse {
    return disableWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, id, request_options);
}
pub fn disableWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, id: []const u8, request_options: options_mod.RequestOptions) !ManagedResponse {
    return mutate(ManagedEndpoint, allocator, config, transport, .POST, id, "/disable", null, request_options);
}
pub fn enable(client: anytype, id: []const u8, request_options: options_mod.RequestOptions) !ManagedResponse {
    return enableWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, id, request_options);
}
pub fn enableWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, id: []const u8, request_options: options_mod.RequestOptions) !ManagedResponse {
    return mutate(ManagedEndpoint, allocator, config, transport, .POST, id, "/enable", null, request_options);
}
pub fn validate(client: anytype, id: []const u8, request: ValidateRequest, request_options: options_mod.RequestOptions) !ValidationResponse {
    return validateWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, id, request, request_options);
}
pub fn validateWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, id: []const u8, request: ValidateRequest, request_options: options_mod.RequestOptions) !ValidationResponse {
    const body = try json.stringifyRequest(allocator, request);
    defer allocator.free(body);
    return mutate(Validation, allocator, config, transport, .POST, id, "/validate", body, request_options);
}
pub fn updatePricing(client: anytype, id: []const u8, request: UpdatePricingRequest, request_options: options_mod.RequestOptions) !GetResponse {
    return updatePricingWithTransport(client.allocator, client.config, http.RealTransport{ .client = &client.http_client }, id, request, request_options);
}
pub fn updatePricingWithTransport(allocator: std.mem.Allocator, config: config_mod.Config, transport: anytype, id: []const u8, request: UpdatePricingRequest, request_options: options_mod.RequestOptions) !GetResponse {
    const body = try json.stringifyRequest(allocator, request);
    defer allocator.free(body);
    return mutate(Endpoint, allocator, config, transport, .PUT, id, "/pricing", body, request_options);
}

test "update private endpoint constructs lifecycle request and owns metadata" {
    const Transport = struct {
        pub fn execute(_: @This(), allocator: std.mem.Allocator, prepared: http.PreparedRequest) !http.HttpResponse {
            try std.testing.expectEqual(std.http.Method.PATCH, prepared.method);
            try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/private-endpoints/a%2Fb", prepared.url);
            try std.testing.expect(prepared.body != null);
            try std.testing.expect(std.mem.indexOf(u8, prepared.body.?, "\"declared_zdr\":false") != null);
            return (http.FakeTransport{ .body = "{\"data\":{\"id\":\"ep_1\",\"status\":\"draft\",\"model_permaslug\":\"vendor/model\",\"model_slug\":null,\"model_name\":null,\"provider_name\":\"Provider\",\"declared_zdr\":null,\"declared_region\":null,\"provider_slug\":null,\"base_url\":null,\"upstream_model_id\":\"deploy\",\"pricing\":{\"prompt\":\"0.01\",\"completion\":\"0.02\"}}}", .headers = &.{.{ .name = "x-request-id", .value = "owned" }} }).execute(allocator, prepared);
        }
    };
    var result = try updateWithTransport(std.testing.allocator, .{ .api_key = "test" }, Transport{}, "a/b", .{ .upstream_model_id = "deploy", .declared_zdr = .{ .value = false } }, .{});
    defer result.deinit();
    try std.testing.expectEqualStrings("owned", result.response_metadata.request_id.?);
    try std.testing.expectError(error.ApiError, updateWithTransport(std.testing.allocator, .{ .api_key = "test" }, http.FakeTransport{ .status = .conflict }, "ep_1", .{ .upstream_model_id = "deploy", .declared_zdr = .{ .value = false } }, .{}));
}
test "delete private endpoint constructs lifecycle request and owns metadata" {
    const Transport = struct {
        pub fn execute(_: @This(), allocator: std.mem.Allocator, prepared: http.PreparedRequest) !http.HttpResponse {
            try std.testing.expectEqual(std.http.Method.DELETE, prepared.method);
            try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/private-endpoints/a%2Fb", prepared.url);
            try std.testing.expect(prepared.body == null);
            return (http.FakeTransport{ .body = "{\"data\":{\"id\":\"ep_1\"}}", .headers = &.{.{ .name = "x-request-id", .value = "owned" }} }).execute(allocator, prepared);
        }
    };
    var result = try deleteWithTransport(std.testing.allocator, .{ .api_key = "test" }, Transport{}, "a/b", .{});
    defer result.deinit();
    try std.testing.expectEqualStrings("owned", result.response_metadata.request_id.?);
    try std.testing.expectError(error.ApiError, deleteWithTransport(std.testing.allocator, .{ .api_key = "test" }, http.FakeTransport{ .status = .conflict }, "ep_1", .{}));
}
test "activate private endpoint constructs lifecycle request and owns metadata" {
    const Transport = struct {
        pub fn execute(_: @This(), allocator: std.mem.Allocator, prepared: http.PreparedRequest) !http.HttpResponse {
            try std.testing.expectEqual(std.http.Method.POST, prepared.method);
            try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/private-endpoints/a%2Fb/activate", prepared.url);
            try std.testing.expect(prepared.body == null);
            return (http.FakeTransport{ .body = "{\"data\":{\"id\":\"ep_1\",\"status\":\"draft\",\"model_permaslug\":\"vendor/model\",\"model_slug\":null,\"model_name\":null,\"provider_name\":\"Provider\",\"created_at\":\"2026-10-18\",\"declared_zdr\":null,\"declared_region\":null}}", .headers = &.{.{ .name = "x-request-id", .value = "owned" }} }).execute(allocator, prepared);
        }
    };
    var result = try activateWithTransport(std.testing.allocator, .{ .api_key = "test" }, Transport{}, "a/b", .{});
    defer result.deinit();
    try std.testing.expectEqualStrings("owned", result.response_metadata.request_id.?);
    try std.testing.expectError(error.ApiError, activateWithTransport(std.testing.allocator, .{ .api_key = "test" }, http.FakeTransport{ .status = .conflict }, "ep_1", .{}));
}
test "disable private endpoint constructs lifecycle request and owns metadata" {
    const Transport = struct {
        pub fn execute(_: @This(), allocator: std.mem.Allocator, prepared: http.PreparedRequest) !http.HttpResponse {
            try std.testing.expectEqual(std.http.Method.POST, prepared.method);
            try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/private-endpoints/a%2Fb/disable", prepared.url);
            try std.testing.expect(prepared.body == null);
            return (http.FakeTransport{ .body = "{\"data\":{\"id\":\"ep_1\",\"status\":\"draft\",\"model_permaslug\":\"vendor/model\",\"model_slug\":null,\"model_name\":null,\"provider_name\":\"Provider\",\"created_at\":\"2026-10-18\",\"declared_zdr\":null,\"declared_region\":null}}", .headers = &.{.{ .name = "x-request-id", .value = "owned" }} }).execute(allocator, prepared);
        }
    };
    var result = try disableWithTransport(std.testing.allocator, .{ .api_key = "test" }, Transport{}, "a/b", .{});
    defer result.deinit();
    try std.testing.expectEqualStrings("owned", result.response_metadata.request_id.?);
    try std.testing.expectError(error.ApiError, disableWithTransport(std.testing.allocator, .{ .api_key = "test" }, http.FakeTransport{ .status = .conflict }, "ep_1", .{}));
}
test "enable private endpoint constructs lifecycle request and owns metadata" {
    const Transport = struct {
        pub fn execute(_: @This(), allocator: std.mem.Allocator, prepared: http.PreparedRequest) !http.HttpResponse {
            try std.testing.expectEqual(std.http.Method.POST, prepared.method);
            try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/private-endpoints/a%2Fb/enable", prepared.url);
            try std.testing.expect(prepared.body == null);
            return (http.FakeTransport{ .body = "{\"data\":{\"id\":\"ep_1\",\"status\":\"draft\",\"model_permaslug\":\"vendor/model\",\"model_slug\":null,\"model_name\":null,\"provider_name\":\"Provider\",\"created_at\":\"2026-10-18\",\"declared_zdr\":null,\"declared_region\":null}}", .headers = &.{.{ .name = "x-request-id", .value = "owned" }} }).execute(allocator, prepared);
        }
    };
    var result = try enableWithTransport(std.testing.allocator, .{ .api_key = "test" }, Transport{}, "a/b", .{});
    defer result.deinit();
    try std.testing.expectEqualStrings("owned", result.response_metadata.request_id.?);
    try std.testing.expectError(error.ApiError, enableWithTransport(std.testing.allocator, .{ .api_key = "test" }, http.FakeTransport{ .status = .conflict }, "ep_1", .{}));
}
test "validate private endpoint constructs lifecycle request and owns metadata" {
    const Transport = struct {
        pub fn execute(_: @This(), allocator: std.mem.Allocator, prepared: http.PreparedRequest) !http.HttpResponse {
            try std.testing.expectEqual(std.http.Method.POST, prepared.method);
            try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/private-endpoints/a%2Fb/validate", prepared.url);
            try std.testing.expect(prepared.body != null);
            return (http.FakeTransport{ .body = "{\"data\":{\"passed\":false,\"checks\":[{\"name\":\"auth_ok\",\"passed\":false,\"reason\":\"future_reason\",\"upstream_status\":502}]}}", .headers = &.{.{ .name = "x-request-id", .value = "owned" }} }).execute(allocator, prepared);
        }
    };
    var result = try validateWithTransport(std.testing.allocator, .{ .api_key = "test" }, Transport{}, "a/b", .{ .workspace_id = "ws" }, .{});
    defer result.deinit();
    try std.testing.expectEqualStrings("owned", result.response_metadata.request_id.?);
    try std.testing.expectError(error.ApiError, validateWithTransport(std.testing.allocator, .{ .api_key = "test" }, http.FakeTransport{ .status = .conflict }, "ep_1", .{ .workspace_id = "ws" }, .{}));
}
test "updatePricing private endpoint constructs lifecycle request and owns metadata" {
    const Transport = struct {
        pub fn execute(_: @This(), allocator: std.mem.Allocator, prepared: http.PreparedRequest) !http.HttpResponse {
            try std.testing.expectEqual(std.http.Method.PUT, prepared.method);
            try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/private-endpoints/a%2Fb/pricing", prepared.url);
            try std.testing.expect(prepared.body != null);
            return (http.FakeTransport{ .body = "{\"data\":{\"id\":\"ep_1\",\"status\":\"draft\",\"model_permaslug\":\"vendor/model\",\"model_slug\":null,\"model_name\":null,\"provider_name\":\"Provider\",\"declared_zdr\":null,\"declared_region\":null,\"provider_slug\":null,\"base_url\":null,\"upstream_model_id\":\"deploy\",\"pricing\":{\"prompt\":\"0.01\",\"completion\":\"0.02\"}}}", .headers = &.{.{ .name = "x-request-id", .value = "owned" }} }).execute(allocator, prepared);
        }
    };
    var result = try updatePricingWithTransport(std.testing.allocator, .{ .api_key = "test" }, Transport{}, "a/b", .{ .pricing = .{ .prompt = "0.01", .completion = "0.02" } }, .{});
    defer result.deinit();
    try std.testing.expectEqualStrings("owned", result.response_metadata.request_id.?);
    try std.testing.expectError(error.ApiError, updatePricingWithTransport(std.testing.allocator, .{ .api_key = "test" }, http.FakeTransport{ .status = .conflict }, "ep_1", .{ .pricing = .{ .prompt = "0.01", .completion = "0.02" } }, .{}));
}
test "private endpoint creation preserves created result" {
    const Transport = struct {
        pub fn execute(_: @This(), allocator: std.mem.Allocator, prepared: http.PreparedRequest) !http.HttpResponse {
            try std.testing.expectEqual(std.http.Method.POST, prepared.method);
            try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/private-endpoints", prepared.url);
            var found = false;
            for (prepared.headers) |h| {
                if (std.ascii.eqlIgnoreCase(h.name, "Idempotency-Key")) {
                    try std.testing.expectEqualStrings("stable", h.value);
                    found = true;
                }
            }
            try std.testing.expect(found);
            return (http.FakeTransport{ .status = .created, .body = "{\"data\":{\"id\":\"ep_1\",\"status\":\"draft\",\"model_permaslug\":\"vendor/model\",\"model_slug\":null,\"model_name\":null,\"provider_name\":\"Provider\",\"created_at\":\"2026-10-18\",\"declared_zdr\":null,\"declared_region\":null}}" }).execute(allocator, prepared);
        }
    };
    var result = try createWithTransport(std.testing.allocator, .{ .api_key = "test" }, Transport{}, .{ .model_permaslug = "vendor/model", .provider_slug = "provider", .upstream_model_id = "deploy", .activate = .{ .workspace_id = "ws" } }, .{ .extra_headers = &.{.{ .name = "Idempotency-Key", .value = "stable" }} });
    defer result.deinit();
    try std.testing.expectEqual(std.http.Status.created, result.status);
    try std.testing.expectEqual(false, result.failure != null);
    try std.testing.expectEqual(true, result.endpoint != null);
}
test "private endpoint creation preserves unprocessable_entity result" {
    const Transport = struct {
        pub fn execute(_: @This(), allocator: std.mem.Allocator, prepared: http.PreparedRequest) !http.HttpResponse {
            try std.testing.expectEqual(std.http.Method.POST, prepared.method);
            try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/private-endpoints", prepared.url);
            var found = false;
            for (prepared.headers) |h| {
                if (std.ascii.eqlIgnoreCase(h.name, "Idempotency-Key")) {
                    try std.testing.expectEqualStrings("stable", h.value);
                    found = true;
                }
            }
            try std.testing.expect(found);
            return (http.FakeTransport{ .status = .unprocessable_entity, .body = "{\"error\":{\"code\":422,\"message\":\"Validation failed\"},\"data\":{\"endpoint\":{\"id\":\"ep_1\",\"status\":\"draft\",\"model_permaslug\":\"vendor/model\",\"model_slug\":null,\"model_name\":null,\"provider_name\":\"Provider\",\"created_at\":\"2026-10-18\",\"declared_zdr\":null,\"declared_region\":null},\"validation\":{\"passed\":false,\"checks\":[]}}}" }).execute(allocator, prepared);
        }
    };
    var result = try createWithTransport(std.testing.allocator, .{ .api_key = "test" }, Transport{}, .{ .model_permaslug = "vendor/model", .provider_slug = "provider", .upstream_model_id = "deploy", .activate = .{ .workspace_id = "ws" } }, .{ .extra_headers = &.{.{ .name = "Idempotency-Key", .value = "stable" }} });
    defer result.deinit();
    try std.testing.expectEqual(std.http.Status.unprocessable_entity, result.status);
    try std.testing.expectEqual(true, result.failure != null);
    try std.testing.expectEqual(true, result.endpoint != null);
    try std.testing.expect(!result.validation.?.passed);
    try std.testing.expectEqualStrings("ep_1", result.endpoint.?.id);
}
test "private endpoint creation preserves forbidden result" {
    const Transport = struct {
        pub fn execute(_: @This(), allocator: std.mem.Allocator, prepared: http.PreparedRequest) !http.HttpResponse {
            try std.testing.expectEqual(std.http.Method.POST, prepared.method);
            try std.testing.expectEqualStrings("https://openrouter.ai/api/v1/private-endpoints", prepared.url);
            var found = false;
            for (prepared.headers) |h| {
                if (std.ascii.eqlIgnoreCase(h.name, "Idempotency-Key")) {
                    try std.testing.expectEqualStrings("stable", h.value);
                    found = true;
                }
            }
            try std.testing.expect(found);
            return (http.FakeTransport{ .status = .forbidden, .body = "{\"error\":{\"code\":403,\"message\":\"Forbidden\"}}" }).execute(allocator, prepared);
        }
    };
    var result = try createWithTransport(std.testing.allocator, .{ .api_key = "test" }, Transport{}, .{ .model_permaslug = "vendor/model", .provider_slug = "provider", .upstream_model_id = "deploy", .activate = .{ .workspace_id = "ws" } }, .{ .extra_headers = &.{.{ .name = "Idempotency-Key", .value = "stable" }} });
    defer result.deinit();
    try std.testing.expectEqual(std.http.Status.forbidden, result.status);
    try std.testing.expectEqual(true, result.failure != null);
    try std.testing.expectEqual(false, result.endpoint != null);
}

test "private endpoint updates distinguish omitted and cleared declarations" {
    const body = try json.stringifyRequest(std.testing.allocator, UpdateRequest{ .upstream_model_id = "model", .declared_region = .clear, .declared_zdr = .{ .value = false } });
    defer std.testing.allocator.free(body);
    var parsed = try json.parseResponse(std.json.Value, std.testing.allocator, body);
    defer parsed.deinit();
    try std.testing.expect(parsed.value.object.get("declared_region").? == .null);
    try std.testing.expect(!parsed.value.object.get("declared_zdr").?.bool);
    try std.testing.expect(!parsed.value.object.contains("base_url"));
}
