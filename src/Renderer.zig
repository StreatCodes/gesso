const std = @import("std");
const sdl3 = @import("sdl3");
const Tree = @import("tree.zig").Tree;
const glyph_atlas = @import("Renderer/glyph_atlas.zig");
const Quad = @import("Renderer/Quad.zig");

const Renderer = @This();

handle: sdl3.render.Renderer,

pub fn init(allocator: std.mem.Allocator, window: sdl3.video.Window) !Renderer {
    const renderer = Renderer{
        .handle = try sdl3.render.Renderer.init(window, null),
    };

    try glyph_atlas.init(allocator, renderer.handle);
    return renderer;
}

pub fn deinit(renderer: *Renderer) void {
    glyph_atlas.deinit();
    renderer.handle.deinit();
}

pub fn render(renderer: *Renderer, allocator: std.mem.Allocator, tree: Tree, width: f32, height: f32) !void {
    try renderer.handle.setDrawColor(.{ .r = 0, .g = 0, .b = 0, .a = 255 });
    try renderer.handle.clear();

    _ = height; //TODO maybe pass into the bounding box?
    var quads: std.ArrayList(Quad) = .empty;
    defer quads.deinit(allocator);
    _ = try tree.root.layout(allocator, .{ .x = 0, .y = 0, .w = width, .h = null }, &quads);

    for (quads.items) |quad| {
        try quad.render(renderer.handle);
    }
}

pub fn present(renderer: *Renderer) !void {
    try renderer.handle.present();
}
