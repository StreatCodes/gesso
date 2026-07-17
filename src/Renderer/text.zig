const std = @import("std");
const sdl3 = @import("sdl3");
const GlyphAtlas = @import("GlyphAtlas.zig");

const RenderOptions = struct {
    max_width: ?u32 = null,
};

pub fn render(renderer: sdl3.render.Renderer, glyph_atlas: *GlyphAtlas, text: []const u8, options: RenderOptions) !void {
    _ = options;

    const ascender = @divTrunc(glyph_atlas.font_face.handle.*.size.*.metrics.ascender, 64);
    const descender = -@divTrunc(glyph_atlas.font_face.handle.*.size.*.metrics.descender, 64);
    const baseline: f32 = @floatFromInt(ascender);
    const max_height: u32 = @intCast(ascender + descender);
    _ = max_height; // TODO may be useful

    var iter = std.unicode.Utf8Iterator{ .bytes = text, .i = 0 };
    var cursor: f32 = 0.0;
    while (iter.nextCodepoint()) |codepoint| {
        const glyph = try glyph_atlas.get(renderer, codepoint);
        if (glyph.texture == null) {
            cursor += @floatFromInt(glyph.advance);
            continue;
        }

        const rect = sdl3.rect.FRect{
            .x = cursor + @as(f32, @floatFromInt(glyph.offset_left)),
            .y = baseline - @as(f32, @floatFromInt(glyph.offset_top)),
            .w = @floatFromInt(glyph.width),
            .h = @floatFromInt(glyph.height),
        };

        try renderer.renderTexture(glyph.texture.?, null, rect);

        cursor += @floatFromInt(glyph.advance);
    }
}
