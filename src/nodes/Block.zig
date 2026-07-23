const std = @import("std");
const tree = @import("../tree.zig");
const parser = @import("../parser.zig");
const Renderer = @import("../Renderer.zig");
const Quad = @import("../Renderer/Quad.zig");

const Block = @This();

//TODO could add a direction, that way each block can go horizontally or vertically (vertical by default)
common: tree.Common = .{},
children: std.ArrayList(tree.Node) = .empty,

pub fn fromTag(allocator: std.mem.Allocator, tag: parser.Tag) !Block {
    var block = Block{};
    for (tag.children) |element| {
        const node = try tree.elementToNode(allocator, element);
        try block.children.append(allocator, node);
    }

    block.common = try .fromAttributes(tag.attributes);

    return block;
}

pub fn layout(block: Block, allocator: std.mem.Allocator, parent_box: tree.BoundingBox, quads: *std.ArrayList(Quad)) !tree.BoundingBox {
    //Store a quad for this block, if there is no explicit height we determine it later
    var box = parent_box.applySize(block.common.width, block.common.height);
    try quads.append(allocator, .{
        .rect = .{
            .x = box.x,
            .y = box.y,
            .w = box.w,
            .h = box.h orelse 0,
        },
    });
    const quad_index = quads.items.len - 1;

    const inner_box = box.applyPadding(block.common.padding);
    var cursor = inner_box.y;
    for (block.children.items) |child| {
        const child_box = try child.layout(allocator, inner_box, quads);
        cursor += child_box.h.?;
    }

    // Update the quad and bounding box height now we know the size of all the children
    if (box.h == null) {
        box.h = cursor;
        if (block.common.padding.bottom == .px) {
            box.h.? += @floatFromInt(block.common.padding.bottom.px);
        }
        quads.items[quad_index].rect.h = box.h.?;
    }

    return box;
}
