const std = @import("std");
const parser = @import("parser.zig");
const styles = @import("styles.zig");

pub const Tree = struct {
    arena: std.heap.ArenaAllocator,
    root: Block = Block{},

    pub fn deinit(tree: Tree) void {
        tree.arena.deinit();
    }
};

pub fn fromDocument(allocator: std.mem.Allocator, document: parser.Document) !Tree {
    var tree = Tree{
        .arena = std.heap.ArenaAllocator.init(allocator),
    };
    const arena = tree.arena.allocator();

    for (document.children) |element| {
        const node = try elementToNode(element);
        try tree.root.children.append(arena, node);
    }

    return tree;
}

fn elementToNode(element: parser.Element) !Node {
    //TODO
    _ = element;
}

pub const Node = union(enum) {
    block: Block,
    text: Text,
};

const Common = struct {
    id: ?u32 = null,
    background_color: styles.Color,
    margin: styles.Margin = .{},
    width: styles.Size = .auto,
    height: styles.Size = .auto,
};

pub const Block = struct {
    children: std.ArrayList(Node) = .empty,
};

pub const Text = struct {
    common: Common,
    content: []const u8,
};
