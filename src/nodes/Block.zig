const std = @import("std");
const tree = @import("../tree.zig");
const parser = @import("../parser.zig");

const Block = @This();

children: std.ArrayList(tree.Node) = .empty,

pub fn fromTag(allocator: std.mem.Allocator, tag: parser.Tag) !Block {
    var block = Block{};
    for (tag.children) |element| {
        const node = try tree.elementToNode(allocator, element);
        try block.children.append(allocator, node);
    }

    return block;
}
