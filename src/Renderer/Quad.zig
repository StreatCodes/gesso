const std = @import("std");
const sdl3 = @import("sdl3");

const Quad = @This();

rect: sdl3.rect.FRect,
background_color: sdl3.pixels.Color = .{ .r = 0, .g = 0, .b = 0, .a = 0 },

pub fn render(quad: Quad, renderer: sdl3.render.Renderer) !void {
    try renderer.setDrawColor(quad.background_color);
    try renderer.renderFillRect(quad.rect);
}
