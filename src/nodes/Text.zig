const std = @import("std");
const tree = @import("../tree.zig");
const parser = @import("../parser.zig");
const Quad = @import("../Renderer/Quad.zig");
const glyph_atlas = @import("../Renderer/glyph_atlas.zig");

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

pub fn layout(text: Text, allocator: std.mem.Allocator, parent_box: tree.BoundingBox, quads: *std.ArrayList(Quad)) !tree.BoundingBox {
    //TODO START this is the exact code we have in block, it's horrendous inlined here, move it to its own Wrapper component
    var box = parent_box.applySize(text.common.width, text.common.height);
    try quads.append(allocator, .{
        .rect = .{
            .x = box.x,
            .y = box.y,
            .w = box.w,
            .h = box.h orelse 0,
        },
        .background_color = text.common.background_color.handle,
    });
    const quad_index = quads.items.len - 1;

    const inner_box = box.applyPadding(text.common.padding);
    //TODO END

    const result = try layoutText(allocator, text.parts.items, inner_box, quads);

    //TODO Most of the remaing code below should also be moved to its own Wrapper component
    // Update the quad and bounding box height now we know the size of all the children
    if (box.h == null) {
        box.h = result.h;
        if (text.common.padding.bottom == .px) {
            box.h.? += text.common.padding.bottom.px;
        }
        quads.items[quad_index].rect.h = box.h.?;
    }

    return box;
}

const Cursor = struct { x: f32, y: f32 };

pub fn layoutText(allocator: std.mem.Allocator, parts: []Part, parent_box: tree.BoundingBox, quads: *std.ArrayList(Quad)) !tree.BoundingBox {
    var atlas = try glyph_atlas.instance();

    var cursor = Cursor{ .x = parent_box.x, .y = parent_box.y };
    for (parts, 0..) |part, i| {
        var iter = std.unicode.Utf8Iterator{ .bytes = part.content, .i = 0 };

        while (iter.nextCodepoint()) |codepoint| {
            const glyph = try atlas.get(codepoint);
            if (cursor.x + @as(f32, @floatFromInt(glyph.advance)) > parent_box.x + parent_box.w) {
                cursor.x = parent_box.x;
                cursor.y += @floatFromInt(atlas.face_info.ascender);
            }
            if (glyph.texture == null) {
                cursor.x += @floatFromInt(glyph.advance);
                continue;
            }

            const quad = Quad{
                .rect = .{
                    .x = cursor.x + @as(f32, @floatFromInt(glyph.offset_left)),
                    .y = cursor.y + atlas.face_info.baseline - @as(f32, @floatFromInt(glyph.offset_top)),
                    .w = @floatFromInt(glyph.width),
                    .h = @floatFromInt(glyph.height),
                },
                .texture = glyph.texture.?,
            };
            try quads.append(allocator, quad);

            cursor.x += @floatFromInt(glyph.advance);
        }

        //Add implicit space between parts
        if (i < parts.len - 1) {
            //TODO print space character
        }
    }

    cursor.y += @floatFromInt(atlas.face_info.ascender);

    return .{
        .x = parent_box.x,
        .y = parent_box.y,
        .w = if (cursor.y > parent_box.y) parent_box.w else cursor.x,
        .h = cursor.y - parent_box.y,
    };
}
