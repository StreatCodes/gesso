const std = @import("std");
const sdl3 = @import("sdl3");
const video = sdl3.video;
const events = sdl3.events;
const tree = @import("tree.zig");
const parser = @import("parser.zig");
const Renderer = @import("Renderer.zig");

pub fn init(allocator: std.mem.Allocator, title: [:0]const u8, screen_width: u32, screen_height: u32, document_text: []const u8) !Instance {
    try sdl3.init(.{ .video = true });
    const window = try video.Window.init(title, screen_width, screen_height, .{});
    const renderer = try Renderer.init(allocator, window);
    const document = try parser.parse(allocator, document_text);
    defer document.deinit();

    return .{
        .window = window,
        .renderer = renderer,
        .tree = try tree.fromDocument(allocator, document),
    };
}

const Instance = struct {
    window: video.Window,
    tree: tree.Tree,
    renderer: Renderer,

    pub fn deinit(instance: *Instance) void {
        instance.tree.deinit();
        instance.renderer.deinit();
        instance.window.deinit();
        sdl3.quit(.{ .video = true });
    }

    /// Blocks until the next input event. Returns false when the app should close.
    pub fn handleInput(instance: *Instance, allocator: std.mem.Allocator) !bool {
        const event = try events.waitAndPop();
        const should_close = switch (event) {
            .quit, .window_close_requested => false,
            else => true,
        };

        const width, const height = try instance.window.getSize(); //TODO not sure if correct size

        try instance.renderer.render(allocator, instance.tree, @floatFromInt(width), @floatFromInt(height));

        return should_close;
    }
};

test {
    std.testing.refAllDecls(@This());
}
