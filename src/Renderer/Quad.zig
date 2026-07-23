const std = @import("std");
const sdl3 = @import("sdl3");

const Quad = @This();

rect: sdl3.rect.FRect,

pub fn render(quad: Quad) !void {
    _ = quad; //TODO
}
