const sdl3 = @import("sdl3");
const gpu = sdl3.gpu;
const video = sdl3.video;
const events = sdl3.events;
const Renderer = @import("Renderer.zig");
const Element = @import("Element.zig");

pub fn init(screen_width: u32, screen_height: u32) !Instance {
    try sdl3.init(.{ .video = true });
    const window = try video.Window.init("Gesso", screen_width, screen_height, .{});
    const device = try gpu.Device.init(.{ .msl = true }, false, null);
    const renderer = try Renderer.init(device, window);

    return .{
        .window = window,
        .device = device,
        .renderer = renderer,
    };
}

const Instance = struct {
    window: video.Window,
    device: gpu.Device,
    renderer: Renderer,

    pub fn deinit(instance: *Instance) void {
        instance.renderer.deinit(instance.device);
        instance.device.deinit();
        instance.window.deinit();

        sdl3.quit(.{ .video = true });
    }

    /// Blocks until the next input event. Returns false when the app should close.
    pub fn handleInput(instance: *Instance) !bool {
        const event = try events.waitAndPop();
        const should_close = switch (event) {
            .quit, .window_close_requested => false,
            else => true,
        };

        const elements: []const Element = &.{
            .{ .text = null, .background_color = .{ .r = 1.0, .g = 0.4, .b = 0.4, .a = 1.0 } },
            .{ .text = null, .background_color = .{ .r = 0.4, .g = 0.4, .b = 1.0, .a = 1.0 } },
        };

        //TODO this should accept a tree instead..?
        try instance.renderer.render(instance.device, elements);

        return should_close;
    }
};
