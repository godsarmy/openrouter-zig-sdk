const std = @import("std");
const openrouter = @import("openrouter");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const api_key = init.minimal.environ.getAlloc(allocator, "OPENROUTER_API_KEY") catch null orelse {
        std.debug.print("Set OPENROUTER_API_KEY to run this example.\n", .{});
        return;
    };
    defer allocator.free(api_key);

    const mode_env = init.minimal.environ.getAlloc(allocator, "OPENROUTER_SERVER_TOOL") catch null;
    defer if (mode_env) |value| allocator.free(value);

    const mode = mode_env orelse "web_search";
    const prompt, const tool = if (std.mem.eql(u8, mode, "web_search")) .{
        "Search the web and summarize one recent Zig language development in two sentences.",
        openrouter.ChatServerTool{ .web_search = .{
            .max_results = 3,
            .search_context_size = "medium",
            .allowed_domains = &.{"ziglang.org"},
        } },
    } else if (std.mem.eql(u8, mode, "web_fetch")) .{
        "Fetch https://ziglang.org/download/ and summarize what the page is for in two sentences.",
        openrouter.ChatServerTool{ .web_fetch = .{
            .max_uses = 2,
            .allowed_domains = &.{"ziglang.org"},
        } },
    } else if (std.mem.eql(u8, mode, "fusion")) .{
        "Compare web search and web fetch tools for developer documentation workflows in three bullets.",
        openrouter.ChatServerTool{ .fusion = .{
            .max_tool_calls = 2,
        } },
    } else {
        std.debug.print("Set OPENROUTER_SERVER_TOOL to web_search, web_fetch, or fusion.\n", .{});
        return;
    };

    var client = try openrouter.Client.init(allocator, init.io, .{
        .api_key = api_key,
    });
    defer client.deinit();

    var response = try client.chat.completions.create(.{
        .model = "openai/gpt-4o-mini",
        .messages = &.{openrouter.ChatMessage{
            .role = .user,
            .content = .{ .text = prompt },
        }},
        .tools = &.{tool},
        .tool_choice = "required",
    }, .{});
    defer response.deinit();

    std.debug.print("server tool: {s}\n\n", .{mode});
    std.debug.print("{s}\n", .{response.choices[0].message.content orelse "<no content>"});
}
