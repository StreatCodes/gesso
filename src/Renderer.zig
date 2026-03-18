const sdl3 = @import("sdl3");
const gpu = sdl3.gpu;
const std = @import("std");
const layout = @import("layout.zig");

const msl_code = @embedFile("shaders/renderer.msl");
const Renderer = @This();

const Vertex = extern struct { x: f32, y: f32 };
const FragmentUniforms = extern struct { background_color: sdl3.pixels.FColor };

window: sdl3.video.Window,
graphics_pipeline: gpu.GraphicsPipeline,
output_texture: gpu.Texture,

pub fn init(device: gpu.Device, window: sdl3.video.Window) !Renderer {
    try device.claimWindow(window);

    const format = try device.getSwapchainTextureFormat(window);
    const width, const height = try window.getSizeInPixels();

    const output_texture = try device.createTexture(.{
        .format = format,
        .usage = .{ .color_target = true, .sampler = true },
        .width = @intCast(width),
        .height = @intCast(height),
        .layer_count_or_depth = 1,
        .num_levels = 1,
    });

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
                .format = format,
            }},
        },
    });

    return .{
        .window = window,
        .output_texture = output_texture,
        .graphics_pipeline = graphics_pipeline,
    };
}

pub fn deinit(renderer: *Renderer, device: gpu.Device) void {
    device.releaseTexture(renderer.output_texture);
    device.releaseGraphicsPipeline(renderer.graphics_pipeline);
    device.releaseWindow(renderer.window);
}

pub fn render(renderer: *Renderer, device: gpu.Device, boxes: []const layout.LayoutBox) !void {
    const command_buffer = try device.acquireCommandBuffer();

    const swapchain_texture, const width, const height = try command_buffer.waitAndAcquireSwapchainTexture(renderer.window);
    if (swapchain_texture == null) {
        try command_buffer.cancel();
        return;
    }

    const vertex_count = boxes.len * 6;
    const vertex_buf_size: u32 = @intCast(vertex_count * @sizeOf(Vertex));

    const transfer_buf = try device.createTransferBuffer(.{ .usage = .upload, .size = vertex_buf_size });
    defer device.releaseTransferBuffer(transfer_buf);

    const mapped: [*]Vertex = @ptrCast(@alignCast(try device.mapTransferBuffer(transfer_buf, false)));
    for (boxes, 0..) |box, i| {
        const rect = box.rect;
        const base = i * 6;
        mapped[base + 0] = .{ .x = rect.x, .y = rect.y }; // TL
        mapped[base + 1] = .{ .x = rect.x + rect.w, .y = rect.y }; // TR
        mapped[base + 2] = .{ .x = rect.x, .y = rect.y + rect.h }; // BL
        mapped[base + 3] = .{ .x = rect.x + rect.w, .y = rect.y }; // TR
        mapped[base + 4] = .{ .x = rect.x + rect.w, .y = rect.y + rect.h }; // BR
        mapped[base + 5] = .{ .x = rect.x, .y = rect.y + rect.h }; // BL
    }
    device.unmapTransferBuffer(transfer_buf);

    const vertex_buf = try device.createBuffer(.{ .usage = .{ .vertex = true }, .size = vertex_buf_size });
    defer device.releaseBuffer(vertex_buf);

    const copy_pass = command_buffer.beginCopyPass();
    copy_pass.uploadToBuffer(
        .{ .transfer_buffer = transfer_buf, .offset = 0 },
        .{ .buffer = vertex_buf, .offset = 0, .size = vertex_buf_size },
        false,
    );
    copy_pass.end();

    const render_pass = command_buffer.beginRenderPass(
        &[_]gpu.ColorTargetInfo{.{
            .texture = renderer.output_texture,
            .load = .clear,
            .clear_color = .{ .r = 0.2, .g = 0.2, .b = 0.2, .a = 1.0 },
            .store = .store,
        }},
        null,
    );
    render_pass.bindGraphicsPipeline(renderer.graphics_pipeline);
    render_pass.bindVertexBuffers(0, &[_]gpu.BufferBinding{.{ .buffer = vertex_buf, .offset = 0 }});

    const screen_size = [2]u32{ width, height };
    command_buffer.pushVertexUniformData(0, std.mem.asBytes(&screen_size));

    for (boxes, 0..) |box, i| {
        const uniforms = FragmentUniforms{ .background_color = box.background_color };
        command_buffer.pushFragmentUniformData(0, std.mem.asBytes(&uniforms));
        render_pass.drawPrimitives(6, 1, @intCast(i * 6), 0);
    }

    render_pass.end();

    command_buffer.blitTexture(.{
        .source = .{
            .texture = renderer.output_texture,
            .mip_level = 0,
            .layer_or_depth_plane = 0,
            .region = .{ .x = 0, .y = 0, .w = @intCast(width), .h = @intCast(height) },
        },
        .destination = .{
            .texture = swapchain_texture.?,
            .mip_level = 0,
            .layer_or_depth_plane = 0,
            .region = .{ .x = 0, .y = 0, .w = @intCast(width), .h = @intCast(height) },
        },
        .load_op = .do_not_care,
        .clear_color = .{},
        .flip_mode = .{},
        .filter = .nearest,
        .cycle = false,
    });

    try command_buffer.submit();
}
