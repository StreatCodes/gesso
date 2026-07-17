const std = @import("std");
const sdl3 = @import("sdl3");
const video = sdl3.video;
const events = sdl3.events;
const tree = @import("tree.zig");
const layout = @import("layout.zig");
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

        // instance.tree.root.render(width: f32)

        const width, _ = try instance.window.getSize(); //TODO not sure if correct size
        _ = width;
        _ = allocator;
        // const quads = try layout.flatten(allocator, instance.tree, @floatFromInt(width));
        // defer allocator.free(quads);

        try instance.renderer.render(instance.tree);

        return should_close;
    }
};

test {
    std.testing.refAllDecls(@This());
}
