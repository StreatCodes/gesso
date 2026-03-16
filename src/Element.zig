const sdl3 = @import("sdl3");
const gpu = sdl3.gpu;

const Element = @This();

const Color = sdl3.pixels.FColor;
const Margin = struct {
    top: u32,
    right: u32,
    bottom: u32,
    left: u32,
};

text: ?[]const u8,
background_color: Color,
margin: Margin = .{ .top = 0, .right = 0, .bottom = 0, .left = 0 },
width: ?u32 = null, //TODO we need some tagged enum type or something for this instead, could be 100%, could be auto, could be 50px
height: ?u32 = null,
