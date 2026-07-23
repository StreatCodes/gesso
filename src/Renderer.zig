const std = @import("std");
const sdl3 = @import("sdl3");
const Tree = @import("tree.zig").Tree;
const text = @import("Renderer/text.zig");
const GlyphAtlas = @import("Renderer/GlyphAtlas.zig");
const Quad = @import("Renderer/Quad.zig");

const Renderer = @This();

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

pub fn render(renderer: *Renderer, allocator: std.mem.Allocator, tree: Tree, width: f32, height: f32) !void {
    try renderer.handle.setDrawColor(.{ .r = 20, .g = 20, .b = 20, .a = 255 });
    try renderer.handle.clear();

    _ = height; //TODO maybe pass into the bounding box?
    var quads: std.ArrayList(Quad) = .empty;
    defer quads.deinit(allocator);
    _ = try tree.root.layout(allocator, .{ .x = 0, .y = 0, .w = width, .h = null }, &quads);

    //TODO render quads

    try renderer.handle.setDrawColor(.{ .r = 255, .g = 0, .b = 255, .a = 255 });
    try renderer.handle.renderFillRect(.{ .x = 0, .y = 0, .w = 100, .h = 200 });

    try text.render(renderer.handle, &renderer.glyph_atlas, "The quick brown fox jumped over the lazy dog!", .{});

    try renderer.handle.present();
}
