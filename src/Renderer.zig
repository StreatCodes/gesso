const sdl3 = @import("sdl3");
const gpu = sdl3.gpu;
const std = @import("std");
const layout = @import("layout.zig");
const TextPipeline = @import("renderer/TextPipeline.zig");

const msl_code = @embedFile("shaders/renderer.msl");
const Renderer = @This();

const Vertex = extern struct { x: f32, y: f32 };
const FragmentUniforms = extern struct { background_color: sdl3.pixels.FColor };

device: gpu.Device,
window: sdl3.video.Window,
graphics_pipeline: gpu.GraphicsPipeline,
text_pipeline: TextPipeline,

pub fn init(allocator: std.mem.Allocator, device: gpu.Device, window: sdl3.video.Window) !Renderer {
    try device.claimWindow(window);

    const format = try device.getSwapchainTextureFormat(window);
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
        .device = device,
        .window = window,
        .graphics_pipeline = graphics_pipeline,
        .text_pipeline = try TextPipeline.init(allocator, device),
    };
}

pub fn deinit(renderer: *Renderer) void {
    renderer.text_pipeline.deinit();
    renderer.device.releaseGraphicsPipeline(renderer.graphics_pipeline);
    renderer.device.releaseWindow(renderer.window);
}

pub fn render(renderer: *Renderer, boxes: []const layout.LayoutBox) !void {
    const text_result = try renderer.text_pipeline.render("Hello, world!", .{});
    defer renderer.device.releaseTexture(text_result.texture); //TODO we don't actually want to discard this, it's a cache
    const command_buffer = try renderer.device.acquireCommandBuffer();

    const swapchain_texture, const width, const height = try command_buffer.waitAndAcquireSwapchainTexture(renderer.window);
    if (swapchain_texture == null) {
        try command_buffer.cancel();
        return;
    }

    const vertex_count = boxes.len * 6;
    const vertex_buf_size: u32 = @intCast(vertex_count * @sizeOf(Vertex));

    const transfer_buf = try renderer.device.createTransferBuffer(.{ .usage = .upload, .size = vertex_buf_size });
    defer renderer.device.releaseTransferBuffer(transfer_buf);

    const mapped: [*]Vertex = @ptrCast(@alignCast(try renderer.device.mapTransferBuffer(transfer_buf, false)));
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
    renderer.device.unmapTransferBuffer(transfer_buf);

    const vertex_buf = try renderer.device.createBuffer(.{ .usage = .{ .vertex = true }, .size = vertex_buf_size });
    defer renderer.device.releaseBuffer(vertex_buf);

    const copy_pass = command_buffer.beginCopyPass();
    copy_pass.uploadToBuffer(
        .{ .transfer_buffer = transfer_buf, .offset = 0 },
        .{ .buffer = vertex_buf, .offset = 0, .size = vertex_buf_size },
        false,
    );
    copy_pass.end();

    const render_pass = command_buffer.beginRenderPass(
        &[_]gpu.ColorTargetInfo{.{
            .texture = swapchain_texture.?,
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

    //TODO temporary blit here
    command_buffer.blitTexture(.{
        .source = .{
            .texture = text_result.texture,
            .mip_level = 0,
            .layer_or_depth_plane = 0,
            .region = .{ .x = 0, .y = 0, .w = text_result.width, .h = text_result.height },
        },
        .destination = .{
            .texture = swapchain_texture.?,
            .mip_level = 0,
            .layer_or_depth_plane = 0,
            .region = .{ .x = 0, .y = 0, .w = text_result.width, .h = text_result.height },
        },
        .load_op = .do_not_care,
        .clear_color = .{},
        .flip_mode = .{},
        .filter = .nearest,
        .cycle = false,
    });

    try command_buffer.submit();
}
