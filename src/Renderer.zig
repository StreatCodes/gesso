const std = @import("std");
const sdl3 = @import("sdl3");
const Tree = @import("tree.zig").Tree;
const text = @import("Renderer/text.zig");
const GlyphAtlas = @import("Renderer/GlyphAtlas.zig");

const Renderer = @This();

// pub const BoundingBox = struct {
//     x: f32,
//     y: f32,
//     w: f32,
//     h: ?f32 = null,
// };

handle: sdl3.render.Renderer,
glyph_atlas: GlyphAtlas,

pub fn init(allocator: std.mem.Allocator, window: sdl3.video.Window) !Renderer {
    return .{
        .handle = try sdl3.render.Renderer.init(window, null),
        .glyph_atlas = try GlyphAtlas.init(allocator),
    };
}

pub fn deinit(renderer: *Renderer) void {
    renderer.glyph_atlas.deinit();
    renderer.handle.deinit();
}

pub fn render(renderer: *Renderer, tree: Tree) !void {
    _ = tree;
    // try instance.renderer.render(flattened);
    try renderer.handle.setDrawColor(.{ .r = 20, .g = 20, .b = 20, .a = 255 });
    try renderer.handle.clear();
    try renderer.handle.setDrawColor(.{ .r = 255, .g = 0, .b = 255, .a = 255 });
    try renderer.handle.renderFillRect(.{ .x = 0, .y = 0, .w = 100, .h = 200 });

    try text.render(renderer.handle, &renderer.glyph_atlas, "The quick brown fox jumped over the lazy dog!", .{});

    try renderer.handle.present();
}
