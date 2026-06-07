const sdl3 = @import("sdl3");
const gpu = sdl3.gpu;
const std = @import("std");
const freetype = @import("freetype");

const msl_code = @embedFile("./text.msl");
const TextPipeline = @This();

const GlyphInfo = struct {
    texture: ?gpu.Texture = null,
    width: u32,
    height: u32,
};

const GlyphAtlas = std.AutoHashMap(u21, GlyphInfo);

const Vertex = extern struct { x: f32, y: f32 };
const FragmentUniforms = extern struct { background_color: sdl3.pixels.FColor };

freetype_lib: freetype.Library,
device: gpu.Device,
graphics_pipeline: gpu.GraphicsPipeline,
// TODO we need to support multiple font sizes, weights, etc. in future.
glyph_atlas: GlyphAtlas,
//TODO support more than one hard coded face and font
font_face: freetype.Face,

pub fn init(allocator: std.mem.Allocator, device: gpu.Device) !TextPipeline {
    const freetype_lib = try freetype.init();
    const face = try freetype.Face.init(freetype_lib, "src/fonts/NotoSans-Regular.ttf", 0);
    try face.set_pixel_sizes(0, 32);

    const vertex_shader = try device.createShader(.{
        .code = msl_code,
        .entry_point = "vertex_main",
        .stage = .vertex,
        .format = .{ .msl = true },
        .num_uniform_buffers = 1,
    });
    defer device.releaseShader(vertex_shader);

    const fragment_shader = try device.createShader(.{
        .code = msl_code,
        .entry_point = "fragment_main",
        .stage = .fragment,
        .format = .{ .msl = true },
        .num_uniform_buffers = 1,
    });
    defer device.releaseShader(fragment_shader);

    const graphics_pipeline = try device.createGraphicsPipeline(.{
        .vertex_shader = vertex_shader,
        .fragment_shader = fragment_shader,
        .vertex_input_state = .{
            .vertex_buffer_descriptions = &[_]gpu.VertexBufferDescription{.{
                .slot = 0,
                .pitch = @sizeOf(Vertex),
                .input_rate = .vertex,
            }},
            .vertex_attributes = &[_]gpu.VertexAttribute{
                .{ .buffer_slot = 0, .location = 0, .format = .f32x2, .offset = 0 },
            },
        },
        .primitive_type = .triangle_list,
        .target_info = .{
            .color_target_descriptions = &[_]gpu.ColorTargetDescription{.{
                .format = .r8g8b8a8_unorm,
            }},
        },
    });

    return .{
        .freetype_lib = freetype_lib,
        .device = device,
        .graphics_pipeline = graphics_pipeline,
        .glyph_atlas = .init(allocator),
        .font_face = face,
    };
}

pub fn deinit(pipeline: *TextPipeline) void {
    var glyph_iter = pipeline.glyph_atlas.iterator();
    while (glyph_iter.next()) |entry| {
        if (entry.value_ptr.texture) |texture| {
            pipeline.device.releaseTexture(texture);
        }
    }

    pipeline.glyph_atlas.deinit();
    pipeline.device.releaseGraphicsPipeline(pipeline.graphics_pipeline);
    pipeline.font_face.deinit();
    freetype.deinit(pipeline.freetype_lib);
}

const RenderOptions = struct {
    max_width: ?u32 = null,
};

/// Renders the given text to a texture on the GPUs, It's the callers responsibility to free
/// the texture.
pub fn render(pipeline: *TextPipeline, allocator: std.mem.Allocator, text: []const u8, options: RenderOptions) !gpu.Texture {
    _ = options;
    const glyph_list = try pipeline.generateGlyphList(allocator, text);
    defer allocator.free(glyph_list);

    // TODO iterate glyph_list, create vertex information

    const width = 8; //TODO this needs to be calculated in the above iterator
    const height = 8; //TODO this needs to be calculated in the above iterator
    const output_texture = try pipeline.device.createTexture(.{
        .format = .r8g8b8a8_unorm,
        .usage = .{ .color_target = true, .sampler = true },
        .width = @intCast(width),
        .height = @intCast(height),
        .layer_count_or_depth = 1,
        .num_levels = 1,
    });

    return output_texture;
}

/// This function will ensure everything required to render the given utf-8 string is created.
/// Returning all the information required to render the string on the GPU. It is the caller's
/// responsibility to free the returned slice.
fn generateGlyphList(pipeline: *TextPipeline, allocator: std.mem.Allocator, text: []const u8) ![]GlyphInfo {
    const string_len = try std.unicode.utf8CountCodepoints(text);
    const string_info = try allocator.alloc(GlyphInfo, string_len);

    var iter = std.unicode.Utf8Iterator{ .bytes = text, .i = 0 };
    var i: usize = 0;
    while (iter.nextCodepoint()) |codepoint| : (i += 1) {
        const texture = pipeline.glyph_atlas.get(codepoint);
        if (texture) |glyph_info| {
            std.debug.print("Found '{u}' in atlas\n", .{codepoint});
            string_info[i] = glyph_info;
            continue;
        }

        std.debug.print("'{u}' not found, creating texture\n", .{codepoint});

        const glyph = try pipeline.font_face.load_glyph(@intCast(codepoint), .{});
        const bitmap = try pipeline.font_face.render_glyph(.normal);

        // TODO need to handle scenario where there is no glyph for the given code point
        if (bitmap) |data| {
            const width: u32 = @abs(glyph.bitmap.pitch);
            const height: u32 = glyph.bitmap.rows;

            const new_texture = try pipeline.uploadGlyph(data, width, height);
            const glyph_info = GlyphInfo{
                .width = width,
                .height = height,
                .texture = new_texture,
            };

            string_info[i] = glyph_info;
            try pipeline.glyph_atlas.put(codepoint, glyph_info);
        }
    }

    return string_info;
}

pub fn uploadGlyph(pipeline: *TextPipeline, bytes: []u8, width: u32, height: u32) !gpu.Texture {
    const texture = try pipeline.device.createTexture(.{
        .format = .r8_unorm,
        .width = width,
        .height = height,
        .usage = .{ .graphics_storage_read = true },
        .num_levels = 1,
    });

    const transfer_buffer = try pipeline.device.createTransferBuffer(.{
        .size = @intCast(bytes.len),
        .usage = .upload,
    });
    defer pipeline.device.releaseTransferBuffer(transfer_buffer);

    const mapped_memory = try pipeline.device.mapTransferBuffer(transfer_buffer, false);
    @memcpy(mapped_memory, bytes);
    pipeline.device.unmapTransferBuffer(transfer_buffer);

    var cmd_buffer = try pipeline.device.acquireCommandBuffer();

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
