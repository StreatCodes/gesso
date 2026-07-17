const std = @import("std");
const sdl3 = @import("sdl3");
const freetype = @import("freetype");

const GlyphAtlas = @This();

pub const Glyph = struct {
    texture: ?sdl3.render.Texture = null,
    width: u32 = 0,
    height: u32 = 0,
    advance: u32,
    offset_top: i32,
    offset_left: i32,
};

allocator: std.mem.Allocator,
freetype_lib: freetype.Library,
font_face: freetype.Face,
cache: std.AutoHashMap(u21, Glyph),

pub fn init(allocator: std.mem.Allocator) !GlyphAtlas {
    const freetype_lib = try freetype.init();
    //TODO support more than one hard coded face and font
    const face = try freetype.Face.init(freetype_lib, "src/fonts/NotoSans-Regular.ttf", 0);
    try face.setPixelSizes(0, 32);

    return .{
        .allocator = allocator,
        .freetype_lib = freetype_lib,
        .font_face = face,
        .cache = .init(allocator),
    };
}

pub fn deinit(atlas: *GlyphAtlas) void {
    var glyph_iter = atlas.cache.iterator();
    while (glyph_iter.next()) |entry| {
        if (entry.value_ptr.texture) |texture| {
            texture.deinit();
        }
    }

    atlas.cache.deinit();
    atlas.font_face.deinit();
    freetype.deinit(atlas.freetype_lib);
}

pub fn get(atlas: *GlyphAtlas, renderer: sdl3.render.Renderer, codepoint: u21) !Glyph {
    if (atlas.cache.get(codepoint)) |glyph| {
        return glyph;
    }

    const glyph_index = atlas.font_face.getCharIndex(@intCast(codepoint));
    const glyph = try atlas.font_face.loadGlyph(glyph_index, .{});
    const bitmap = try atlas.font_face.renderGlyph(.normal);

    var glyph_info = Glyph{
        .advance = @intCast(@divTrunc(glyph.advance.x, 64)),
        .offset_top = glyph.bitmap_top,
        .offset_left = glyph.bitmap_left,
    };

    if (bitmap) |data| {
        std.debug.print("'{u}' not found, creating texture\n", .{codepoint});
        const width: u32 = @abs(glyph.bitmap.pitch);
        const height: u32 = glyph.bitmap.rows;

        const new_texture = try renderer.createTexture(.array_rgba_32, .static, width, height);
        const texture_data = try expandTextureData(atlas.allocator, data);
        defer atlas.allocator.free(texture_data);

        try new_texture.update(null, texture_data.ptr, width * 4);

        glyph_info.width = width;
        glyph_info.height = height;
        glyph_info.texture = new_texture;

        try atlas.cache.put(codepoint, glyph_info);
    }

    return glyph_info;
}

/// Takes a grayscale buffer and returns a RGBA equivalent. It is the caller's
/// responsibility to free the returned slice.
fn expandTextureData(allocator: std.mem.Allocator, grayscale: []u8) ![]u8 {
    const expanded = try allocator.alloc(u8, grayscale.len * 4);
    for (grayscale, 0..) |v, i| {
        const offset = i * 4;
        expanded[offset + 0] = 255; // R
        expanded[offset + 1] = 255; // G
        expanded[offset + 2] = 255; // B
        expanded[offset + 3] = v; // A
    }

    return expanded;
}
