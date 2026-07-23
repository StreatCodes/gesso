const std = @import("std");
const tree = @import("../tree.zig");
const parser = @import("../parser.zig");
const Quad = @import("../Renderer/Quad.zig");

const Text = @This();

pub const Format = struct {
    bold: bool = false,
    underline: bool = false,
    italic: bool = false,
    strike_through: bool = false,
};

const Part = struct {
    format: Format = .{},
    content: []const u8 = "",
};

common: tree.Common = .{},
parts: std.ArrayList(Part) = .empty,

pub fn fromTag(allocator: std.mem.Allocator, tag: parser.Tag) !Text {
    var parts: std.ArrayList(Part) = .empty;
    for (tag.children) |child| {
        try resolveParts(allocator, &parts, .{}, child);
    }

    return .{
        .common = try .fromAttributes(tag.attributes),
        .parts = parts,
    };
}

fn resolveParts(allocator: std.mem.Allocator, parts: *std.ArrayList(Part), format: Format, element: parser.Element) !void {
    switch (element) {
        .tag => |tag| {
            var new_format = format;
            // only allow, <b>, <u>, <i>, <s>
            if (tag.name.len > 1) return tree.Error.InvalidTextChild;
            switch (tag.name[0]) {
                'b' => new_format.bold = true,
                'u' => new_format.underline = true,
                'i' => new_format.italic = true,
                's' => new_format.strike_through = true,
                else => {
                    return tree.Error.InvalidTextChild;
                },
            }

            for (tag.children) |child| {
                try resolveParts(allocator, parts, new_format, child);
            }
        },
        .text => |text| {
            try parts.append(allocator, .{
                .format = format,
                .content = text,
            });
        },
    }
}

pub fn layout(text: Text, allocator: std.mem.Allocator, bbox: tree.BoundingBox, quads: *std.ArrayList(Quad)) !tree.BoundingBox {
    _ = allocator;
    _ = text;
    _ = quads;

    return tree.BoundingBox{ .x = bbox.x, .y = bbox.y, .w = 20, .h = 20 }; //TODO real values
}
