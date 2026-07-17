const std = @import("std");
const sdl3 = @import("sdl3");

pub const Error = error{InvalidColor};

pub const Color = struct {
    handle: sdl3.pixels.Color,

    pub fn fromString(str: []const u8) !Color {
        if (str.len != 9 or str[0] != '#') return Error.InvalidColor;

        return .{
            .handle = .{
                .r = try std.fmt.parseInt(u8, str[1..2], 16),
                .g = try std.fmt.parseInt(u8, str[1..2], 16),
                .b = try std.fmt.parseInt(u8, str[1..2], 16),
                .a = 255, //TODO we could get this value
            },
        };
    }
};

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
