const std = @import("std");
const parser = @import("parser.zig");
const styles = @import("styles.zig");

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
        const node = try elementToNode(element);
        try tree.root.children.append(arena, node);
    }

    return tree;
}

fn elementToNode(element: parser.Element) !Node {
    switch (element) {
        .tag => |tag| {
            return try Node.fromTag(tag);
        },
        .text => {
            return Error.InvalidTextChild;
        },
    }
}

pub const Node = union(enum) {
    block: Block,
    text: Text,

    pub fn fromTag(tag: parser.Tag) !Node {
        const Tag = std.meta.Tag(Node);
        const node = std.meta.stringToEnum(Tag, tag.name) orelse {
            return Error.UnknownNode;
        };

        switch (node) {
            .block => return .{ .block = Block.fromTag(tag) },
            .text => return .{ .text = Text.fromTag(tag) },
        }
    }
};

const Common = struct {
    id: ?u32 = null,
    background_color: styles.Color = .{ .r = 0.2, .g = 0.2, .b = 0.2, .a = 1.0 },
    margin: styles.Margin = .{},
    width: styles.Size = .auto,
    height: styles.Size = .auto,
};

pub const Block = struct {
    children: std.ArrayList(Node) = .empty,

    pub fn fromTag(tag: parser.Tag) Block {
        //TODO
        _ = tag;
        return .{};
    }
};

pub const Text = struct {
    common: Common = Common{},
    content: []const u8 = "",

    pub fn fromTag(tag: parser.Tag) Text {
        //TODO
        _ = tag;
        return .{};
    }
};
