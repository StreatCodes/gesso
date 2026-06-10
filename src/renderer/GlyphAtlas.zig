const std = @import("std");
const sdl3 = @import("sdl3");
const freetype = @import("freetype");

const GlyphAtlas = @This();

pub const Glyph = struct {
    texture: ?sdl3.gpu.Texture = null,
    width: u32 = 0,
    height: u32 = 0,
    advance: u32,
    offset_top: i32,
    offset_left: i32,
};

freetype_lib: freetype.Library,
font_face: freetype.Face,
cache: std.AutoHashMap(u21, Glyph),

pub fn init(allocator: std.mem.Allocator) !GlyphAtlas {
    const freetype_lib = try freetype.init();
    //TODO support more than one hard coded face and font
    const face = try freetype.Face.init(freetype_lib, "src/fonts/NotoSans-Regular.ttf", 0);
    try face.set_pixel_sizes(0, 32);

    return .{
        .freetype_lib = freetype_lib,
        .font_face = face,
        .cache = .init(allocator),
    };
}

pub fn deinit(atlas: *GlyphAtlas, device: sdl3.gpu.Device) void {
    var glyph_iter = atlas.cache.iterator();
    while (glyph_iter.next()) |entry| {
        if (entry.value_ptr.texture) |texture| {
            device.releaseTexture(texture);
        }
    }

    atlas.cache.deinit();
    atlas.font_face.deinit();
    freetype.deinit(atlas.freetype_lib);
}

pub fn get(atlas: *GlyphAtlas, device: sdl3.gpu.Device, codepoint: u21) !Glyph {
    if (atlas.cache.get(codepoint)) |glyph| {
        return glyph;
    }

    const glyph_index = atlas.font_face.get_char_index(@intCast(codepoint));
    const glyph = try atlas.font_face.load_glyph(glyph_index, .{});
    const bitmap = try atlas.font_face.render_glyph(.normal);

    var glyph_info = Glyph{
        .advance = @intCast(@divTrunc(glyph.advance.x, 64)),
        .offset_top = glyph.bitmap_top,
        .offset_left = glyph.bitmap_left,
    };

    if (bitmap) |data| {
        std.debug.print("'{u}' not found, creating texture\n", .{codepoint});
        const width: u32 = @abs(glyph.bitmap.pitch);
        const height: u32 = glyph.bitmap.rows;

        const new_texture = try uploadGlyph(device, data, width, height);
        glyph_info.width = width;
        glyph_info.height = height;
        glyph_info.texture = new_texture;

        try atlas.cache.put(codepoint, glyph_info);
    } else {
        std.debug.print("'{u}' not found, no glyph for codepoint\n", .{codepoint});
    }

    return glyph_info;
}

fn uploadGlyph(device: sdl3.gpu.Device, bytes: []u8, width: u32, height: u32) !sdl3.gpu.Texture {
    const texture = try device.createTexture(.{
        .format = .r8_unorm,
        .width = width,
        .height = height,
        .usage = .{ .sampler = true },
        .num_levels = 1,
        .layer_count_or_depth = 1,
    });

    const transfer_buffer = try device.createTransferBuffer(.{
        .size = @intCast(bytes.len),
        .usage = .upload,
    });
    defer device.releaseTransferBuffer(transfer_buffer);

    const mapped_memory = try device.mapTransferBuffer(transfer_buffer, false);
    @memcpy(mapped_memory, bytes);
    device.unmapTransferBuffer(transfer_buffer);

    var cmd_buffer = try device.acquireCommandBuffer();

    const copy_pass = cmd_buffer.beginCopyPass();
    copy_pass.uploadToTexture(.{
        .offset = 0,
        .transfer_buffer = transfer_buffer,
    }, .{
        .texture = texture,
        .width = width,
        .height = height,
        .depth = 1,
    }, false);

    copy_pass.end();
    try cmd_buffer.submit();

    return texture;
}
