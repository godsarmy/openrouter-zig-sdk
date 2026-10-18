//! Manual integration suite, grouped by API surface.
test {
    _ = @import("integration/discovery.zig");
    _ = @import("integration/chat.zig");
    _ = @import("integration/messages.zig");
    _ = @import("integration/responses.zig");
    _ = @import("integration/generation.zig");
    _ = @import("integration/management.zig");
    _ = @import("integration/support.zig");
}
