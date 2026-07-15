const std = @import("std");
const sdl3 = @import("sdl3");
const video = sdl3.video;
const events = sdl3.events;
const tree = @import("tree.zig");
const layout = @import("layout.zig");
const text = @import("renderer/text.zig");
const GlyphAtlas = @import("renderer/GlyphAtlas.zig");
const parser = @import("parser.zig");

pub fn init(allocator: std.mem.Allocator, title: [:0]const u8, screen_width: u32, screen_height: u32, document: []const u8) !Instance {
    try sdl3.init(.{ .video = true });
    const window = try video.Window.init(title, screen_width, screen_height, .{});
    const renderer = try sdl3.render.Renderer.init(window, null);
    const doc = try parser.parse(allocator, document);
    //TODO use the doc....
    defer doc.deinit();

    return .{
        .window = window,
        .renderer = renderer,
        // .root = try parser.parse(allocator, document),
        .glyph_atlas = try GlyphAtlas.init(allocator),
    };
}

const Instance = struct {
    window: video.Window,
    renderer: sdl3.render.Renderer,
    // root: elements.Block,
    glyph_atlas: GlyphAtlas,

    pub fn deinit(instance: *Instance) void {
        instance.glyph_atlas.deinit();
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

        const width, _ = try instance.window.getSize(); //TODO not sure if correct size
        _ = width;
        _ = allocator;
        // const flattened = try layout.flatten(allocator, instance.root, @floatFromInt(width));
        // defer allocator.free(flattened);

        // try instance.renderer.render(flattened);
        try instance.renderer.setDrawColor(.{ .r = 20, .g = 20, .b = 20, .a = 255 });
        try instance.renderer.clear();
        try instance.renderer.setDrawColor(.{ .r = 255, .g = 0, .b = 255, .a = 255 });
        try instance.renderer.renderFillRect(.{ .x = 0, .y = 0, .w = 100, .h = 200 });

        try text.render(instance.renderer, &instance.glyph_atlas, "The quick brown fox jumped over the lazy dog!", .{});

        try instance.renderer.present();

        return should_close;
    }
};

test {
    std.testing.refAllDecls(@This());
}
