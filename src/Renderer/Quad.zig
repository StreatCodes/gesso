const std = @import("std");
const sdl3 = @import("sdl3");

const Quad = @This();

rect: sdl3.rect.FRect,
background_color: sdl3.pixels.Color = .{ .r = 0, .g = 0, .b = 0, .a = 0 },
texture: ?sdl3.render.Texture = null,

pub fn render(quad: Quad, renderer: sdl3.render.Renderer) !void {
    if (quad.texture) |texture| {
        try renderer.renderTexture(texture, null, quad.rect);
    } else {
        try renderer.setDrawColor(quad.background_color);
        try renderer.renderFillRect(quad.rect);
    }
}
