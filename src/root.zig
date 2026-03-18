const std = @import("std");
const sdl3 = @import("sdl3");
const gpu = sdl3.gpu;
const video = sdl3.video;
const events = sdl3.events;
const Renderer = @import("Renderer.zig");
const Element = @import("Element.zig");
const layout = @import("layout.zig");

pub fn init(title: [:0]const u8, screen_width: u32, screen_height: u32) !Instance {
    try sdl3.init(.{ .video = true });
    const window = try video.Window.init(title, screen_width, screen_height, .{});
    const device = try gpu.Device.init(.{ .msl = true }, false, null);
    const renderer = try Renderer.init(device, window);

    const root: Element = .{
        .background_color = .{ .r = 0.2, .g = 0.2, .b = 0.2, .a = 1.0 },
        .data = .{ .block = .{ .children = @constCast(&[_]Element{
            .{ .background_color = .{ .r = 1.0, .g = 0.4, .b = 0.4, .a = 1.0 }, .width = .{ .px = 400 }, .height = .{ .px = 200 }, .data = .{ .block = .{ .children = &.{} } } },
            .{ .background_color = .{ .r = 0.4, .g = 0.4, .b = 1.0, .a = 1.0 }, .width = .{ .px = 600 }, .height = .{ .px = 150 }, .data = .{ .block = .{ .children = &.{} } } },
        }) } },
    };

    return .{
        .window = window,
        .device = device,
        .renderer = renderer,
        .root = root,
    };
}

const Instance = struct {
    window: video.Window,
    device: gpu.Device,
    renderer: Renderer,
    root: Element,

    pub fn deinit(instance: *Instance) void {
        instance.renderer.deinit(instance.device);
        instance.device.deinit();
        instance.window.deinit();
        sdl3.quit(.{ .video = true });
    }

    /// Blocks until the next input event. Returns false when the app should close.
    pub fn handleInput(instance: *Instance, allocator: std.mem.Allocator) !bool {
        const event = try events.waitAndPop();
        const should_close = switch (event) {
            .quit, .window_close_requested => false,
            else => true,
        };

        const width, _ = try instance.window.getSize(); //TODO not sure if correct size
        const flattened = try layout.flatten(allocator, instance.root, @floatFromInt(width));
        defer allocator.free(flattened);

        try instance.renderer.render(instance.device, flattened);

        return should_close;
    }
};
