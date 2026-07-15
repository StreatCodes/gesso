const std = @import("std");
const parser = @import("parser.zig");
const styles = @import("styles.zig");

const Block = @import("nodes/Block.zig");
const Text = @import("nodes/Text.zig");

const Error = error{
    InvalidTextChild,
    UnknownNode,
};

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
        const node = try elementToNode(arena, element);
        try tree.root.children.append(arena, node);
    }

    return tree;
}

const NError = std.mem.Allocator.Error || Error;
pub fn elementToNode(allocator: std.mem.Allocator, element: parser.Element) NError!Node {
    switch (element) {
        .tag => |tag| {
            return try Node.fromTag(allocator, tag);
        },
        .text => {
            return Error.InvalidTextChild;
        },
    }
}

pub const Node = union(enum) {
    block: Block,
    text: Text,

    pub fn fromTag(allocator: std.mem.Allocator, tag: parser.Tag) !Node {
        const Tag = std.meta.Tag(Node);
        const node = std.meta.stringToEnum(Tag, tag.name) orelse {
            return Error.UnknownNode;
        };

        switch (node) {
            .block => return .{ .block = try Block.fromTag(allocator, tag) },
            .text => return .{ .text = Text.fromTag(tag) },
        }
    }
};

pub const Common = struct {
    id: ?u32 = null,
    background_color: styles.Color = .{ .r = 0.2, .g = 0.2, .b = 0.2, .a = 1.0 },
    margin: styles.Margin = .{},
    width: styles.Size = .auto,
    height: styles.Size = .auto,
};
