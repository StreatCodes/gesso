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

const Vertex = extern struct { x: f32, y: f32, uv_x: f32, uv_y: f32 };
const FragmentUniforms = extern struct { background_color: sdl3.pixels.FColor };

freetype_lib: freetype.Library,
device: gpu.Device,
graphics_pipeline: gpu.GraphicsPipeline,
sampler: gpu.Sampler,
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
        // .num_uniform_buffers = 1,
        .num_samplers = 1,
    });
    defer device.releaseShader(fragment_shader);

    const sampler = try device.createSampler(.{ .max_lod = 1000.0 });

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
                .{ .buffer_slot = 0, .location = 1, .format = .f32x2, .offset = @sizeOf(f32) * 2 },
            },
        },
        .primitive_type = .triangle_strip,
        .target_info = .{
            .color_target_descriptions = &[_]gpu.ColorTargetDescription{.{
                .format = .r8g8b8a8_unorm,
                .blend_state = .{
                    .enable_blend = true,
                    .source_color = .src_alpha,
                    .destination_color = .one_minus_src_alpha,
                    .color_blend = .add,
                    .source_alpha = .one,
                    .destination_alpha = .one_minus_src_alpha,
                    .alpha_blend = .add,
                },
            }},
        },
    });

    return .{
        .freetype_lib = freetype_lib,
        .device = device,
        .sampler = sampler,
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
    pipeline.device.releaseSampler(pipeline.sampler);
    pipeline.device.releaseGraphicsPipeline(pipeline.graphics_pipeline);
    pipeline.font_face.deinit();
    freetype.deinit(pipeline.freetype_lib);
}

const RenderOptions = struct {
    max_width: ?u32 = null,
};

const TextureResult = struct {
    texture: gpu.Texture,
    width: u32,
    height: u32,
};

/// Renders the given text to a texture on the GPUs, It's the callers responsibility to free
/// the texture.
pub fn render(pipeline: *TextPipeline, allocator: std.mem.Allocator, text: []const u8, options: RenderOptions) !TextureResult {
    _ = options;
    const glyph_list = try pipeline.generateGlyphList(allocator, text);
    defer allocator.free(glyph_list);

    const vertex_count = glyph_list.len * 4;
    const vertex_buf_size: u32 = @intCast(vertex_count * @sizeOf(Vertex));

    const transfer_buf = try pipeline.device.createTransferBuffer(.{ .usage = .upload, .size = vertex_buf_size });
    defer pipeline.device.releaseTransferBuffer(transfer_buf);

    var cursor: f32 = 0.0;
    const mapped: [*]Vertex = @ptrCast(@alignCast(try pipeline.device.mapTransferBuffer(transfer_buf, false)));
    for (glyph_list, 0..) |glyph_info, i| {
        const width: f32 = @floatFromInt(glyph_info.width);
        const height: f32 = @floatFromInt(glyph_info.height);
        const base = i * 4;

        mapped[base + 0] = .{ .x = cursor, .y = 0, .uv_x = 0.0, .uv_y = 0.0 }; // TL
        mapped[base + 1] = .{ .x = cursor + width, .y = 0, .uv_x = 1.0, .uv_y = 0.0 }; // TR
        mapped[base + 2] = .{ .x = cursor, .y = height, .uv_x = 0.0, .uv_y = 1.0 }; // BL
        mapped[base + 3] = .{ .x = cursor + width, .y = height, .uv_x = 1.0, .uv_y = 1.0 }; // BR

        cursor += width;
    }
    pipeline.device.unmapTransferBuffer(transfer_buf);

    const vertex_buf = try pipeline.device.createBuffer(.{ .usage = .{ .vertex = true }, .size = vertex_buf_size });
    defer pipeline.device.releaseBuffer(vertex_buf);

    const output_height: u32 = 40; //TODO this needs to be calculated in the above iterator
    const output_width: u32 = @intFromFloat(cursor);
    const output_texture = try pipeline.device.createTexture(.{
        .format = .r8g8b8a8_unorm,
        .usage = .{ .color_target = true, .sampler = true },
        .width = output_width,
        .height = output_height,
        .layer_count_or_depth = 1,
        .num_levels = 1,
    });

    const command_buffer = try pipeline.device.acquireCommandBuffer();
    const copy_pass = command_buffer.beginCopyPass();
    copy_pass.uploadToBuffer(
        .{ .transfer_buffer = transfer_buf, .offset = 0 },
        .{ .buffer = vertex_buf, .offset = 0, .size = vertex_buf_size },
        false,
    );
    copy_pass.end();

    const render_pass = command_buffer.beginRenderPass(
        &[_]gpu.ColorTargetInfo{.{
            .texture = output_texture,
            .load = .clear,
            .clear_color = .{ .r = 0, .g = 0, .b = 0, .a = 0 },
            .store = .store,
        }},
        null,
    );
    render_pass.bindGraphicsPipeline(pipeline.graphics_pipeline);

    const texture_size = [2]u32{ output_width, output_height };
    command_buffer.pushVertexUniformData(0, std.mem.asBytes(&texture_size));

    for (glyph_list, 0..) |glyph_info, _i| {
        const texture = glyph_info.texture orelse continue;

        const i: u32 = @intCast(_i);
        render_pass.bindVertexBuffers(0, &[_]gpu.BufferBinding{.{ .buffer = vertex_buf, .offset = i * 4 * @sizeOf(Vertex) }});
        render_pass.bindFragmentSamplers(0, &[_]gpu.TextureSamplerBinding{.{
            .texture = texture,
            .sampler = pipeline.sampler,
        }});

        // const uniforms = FragmentUniforms{ .background_color = box.background_color };
        // command_buffer.pushFragmentUniformData(0, std.mem.asBytes(&uniforms));

        render_pass.drawPrimitives(4, 1, 0, 0);
    }

    render_pass.end();
    try command_buffer.submit();

    return .{
        .texture = output_texture,
        .width = output_width,
        .height = output_height,
    };
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
            string_info[i] = glyph_info;
            continue;
        }

        const glyph_index = pipeline.font_face.get_char_index(@intCast(codepoint));
        const glyph = try pipeline.font_face.load_glyph(glyph_index, .{});
        const bitmap = try pipeline.font_face.render_glyph(.normal);

        // TODO need to handle scenario where there is no glyph for the given code point
        if (bitmap) |data| {
            std.debug.print("'{u}' not found, creating texture\n", .{codepoint});
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
        } else {
            std.debug.print("'{u}' not found, no glyph for codepoint\n", .{codepoint});
        }
    }

    return string_info;
}

pub fn uploadGlyph(pipeline: *TextPipeline, bytes: []u8, width: u32, height: u32) !gpu.Texture {
    const texture = try pipeline.device.createTexture(.{
        .format = .r8_unorm,
        .width = width,
        .height = height,
        .usage = .{ .sampler = true }, //TODO is this correct?
        .num_levels = 1,
        .layer_count_or_depth = 1,
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
