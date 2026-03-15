const sdl3 = @import("sdl3");
const gpu = sdl3.gpu;

const Element = @This();

const Color = struct {
    r: f32,
    g: f32,
    b: f32,
    a: f32,
};

const Margin = struct {
    top: i32,
    right: i32,
    bottom: i32,
    left: i32,
};

text: ?[]const u8,
background_color: Color,
margin: Margin = .{ .top = 0, .right = 0, .bottom = 0, .left = 0 },
