const std = @import("std");
const sdl3 = @import("sdl3");

pub const Error = error{
    InvalidColor,
    InvalidSize,
    InvalidMargin,
};

pub const Color = struct {
    handle: sdl3.pixels.Color,

    pub fn fromString(str: []const u8) !Color {
        if (str.len != 7 or str[0] != '#') return Error.InvalidColor;

        return .{
            .handle = .{
                .r = try std.fmt.parseInt(u8, str[1..3], 16),
                .g = try std.fmt.parseInt(u8, str[3..5], 16),
                .b = try std.fmt.parseInt(u8, str[5..7], 16),
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

    pub fn fromString(str: []const u8) !Size {
        if (std.mem.eql(u8, str, "auto")) {
            return .auto;
        }
        if (!std.mem.endsWith(u8, str, "px")) return Error.InvalidSize;
        const value = str[0 .. str.len - 2];

        return .{ .px = try std.fmt.parseInt(u32, value, 10) };
    }
};

pub const Margin = struct {
    top: Size = .{ .px = 0 },
    right: Size = .{ .px = 0 },
    bottom: Size = .{ .px = 0 },
    left: Size = .{ .px = 0 },

    pub fn fromString(str: []const u8) !Margin {
        const part_count = std.mem.countScalar(u8, str, ' ') + 1;
        var parts_iter = std.mem.splitScalar(u8, str, ' ');

        if (part_count == 1) {
            return .{
                .top = try .fromString(str),
                .right = try .fromString(str),
                .bottom = try .fromString(str),
                .left = try .fromString(str),
            };
        }

        if (part_count == 2) {
            const vertical = try Size.fromString(parts_iter.next().?);
            const horizontal = try Size.fromString(parts_iter.next().?);

            return .{
                .top = vertical,
                .right = horizontal,
                .bottom = vertical,
                .left = horizontal,
            };
        }

        if (part_count == 4) {
            return .{
                .top = try Size.fromString(parts_iter.next().?),
                .right = try Size.fromString(parts_iter.next().?),
                .bottom = try Size.fromString(parts_iter.next().?),
                .left = try Size.fromString(parts_iter.next().?),
            };
        }

        return Error.InvalidMargin;
    }
};
