const sdl3 = @import("sdl3");

pub const Color = sdl3.pixels.FColor;

pub const Size = union(enum) {
    /// Fixed size in pixels
    px: u32,
    /// Size to content
    auto,
};

pub const Margin = struct {
    top: u32 = 0,
    right: u32 = 0,
    bottom: u32 = 0,
    left: u32 = 0,
};
