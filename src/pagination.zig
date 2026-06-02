//! Offset/limit pagination helpers.

const std = @import("std");

pub const OffsetLimit = struct {
    offset: u64 = 0,
    limit: u64 = 100,

    pub fn queryString(self: OffsetLimit, allocator: std.mem.Allocator) ![]u8 {
        return std.fmt.allocPrint(allocator, "offset={d}&limit={d}", .{ self.offset, self.limit });
    }
};

pub fn Pager(
    comptime Page: type,
    comptime Context: type,
    comptime fetchPage: *const fn (*Context, OffsetLimit) anyerror!?Page,
    comptime deinitContext: ?*const fn (*Context) void,
) type {
    return struct {
        const Self = @This();

        context: Context,
        page: OffsetLimit = .{},
        done: bool = false,

        pub fn init(context: Context, page: OffsetLimit) Self {
            return .{
                .context = context,
                .page = page,
                .done = page.limit == 0,
            };
        }

        pub fn next(self: *Self) !?Page {
            if (self.done) return null;

            const current_limit = self.page.limit;
            const result = try fetchPage(&self.context, self.page) orelse {
                self.done = true;
                return null;
            };

            const item_count = pageItemCount(result);
            if (item_count < current_limit) {
                self.done = true;
            } else {
                self.page.offset += item_count;
            }

            return result;
        }

        pub fn deinit(self: *Self) void {
            if (deinitContext) |deinit_fn| deinit_fn(&self.context);
            self.* = undefined;
        }
    };
}

fn pageItemCount(page: anytype) u64 {
    const Page = @TypeOf(page);
    if (@hasField(Page, "data")) return page.data.len;
    @compileError("paginated page type must expose a data field");
}

test "offset limit builds query string" {
    const query = try (OffsetLimit{ .offset = 25, .limit = 50 }).queryString(std.testing.allocator);
    defer std.testing.allocator.free(query);

    try std.testing.expectEqualStrings("offset=25&limit=50", query);
}

test "pager advances offsets and stops after short page" {
    const MockPage = struct { data: []const u32 };
    const MockContext = struct {
        calls: usize = 0,
        offsets: [4]u64 = .{ 0, 0, 0, 0 },
        limits: [4]u64 = .{ 0, 0, 0, 0 },

        fn fetch(self: *@This(), page: OffsetLimit) anyerror!?MockPage {
            self.offsets[self.calls] = page.offset;
            self.limits[self.calls] = page.limit;
            defer self.calls += 1;

            return switch (self.calls) {
                0 => MockPage{ .data = &.{ 1, 2 } },
                1 => MockPage{ .data = &.{3} },
                else => null,
            };
        }
    };
    const MockPager = Pager(MockPage, MockContext, MockContext.fetch, null);

    var pager = MockPager.init(.{}, .{ .offset = 10, .limit = 2 });
    defer pager.deinit();

    const first = (try pager.next()).?;
    try std.testing.expectEqual(@as(usize, 2), first.data.len);

    const second = (try pager.next()).?;
    try std.testing.expectEqual(@as(usize, 1), second.data.len);

    try std.testing.expectEqual(null, try pager.next());
    try std.testing.expectEqual(@as(usize, 2), pager.context.calls);
    try std.testing.expectEqual(@as(u64, 10), pager.context.offsets[0]);
    try std.testing.expectEqual(@as(u64, 12), pager.context.offsets[1]);
    try std.testing.expectEqual(@as(u64, 2), pager.context.limits[0]);
    try std.testing.expectEqual(@as(u64, 2), pager.context.limits[1]);
}

test "pager deinitializes owned context" {
    const MockPage = struct { data: []const u8 };
    const MockContext = struct {
        deinit_count: *u32,

        fn fetch(_: *@This(), _: OffsetLimit) anyerror!?MockPage {
            return null;
        }

        fn deinit(self: *@This()) void {
            self.deinit_count.* += 1;
        }
    };
    const MockPager = Pager(MockPage, MockContext, MockContext.fetch, MockContext.deinit);

    var deinit_count: u32 = 0;
    var pager = MockPager.init(.{ .deinit_count = &deinit_count }, .{});
    pager.deinit();

    try std.testing.expectEqual(@as(u32, 1), deinit_count);
}

test "pager with zero limit returns null without fetching" {
    const MockPage = struct { data: []const u8 };
    const MockContext = struct {
        calls: usize = 0,

        fn fetch(self: *@This(), _: OffsetLimit) anyerror!?MockPage {
            self.calls += 1;
            return MockPage{ .data = &.{} };
        }
    };
    const MockPager = Pager(MockPage, MockContext, MockContext.fetch, null);

    var pager = MockPager.init(.{}, .{ .limit = 0 });
    defer pager.deinit();

    try std.testing.expectEqual(null, try pager.next());
    try std.testing.expectEqual(@as(usize, 0), pager.context.calls);
}
