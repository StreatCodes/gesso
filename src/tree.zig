const std = @import("std");
const parser = @import("parser.zig");
const styles = @import("styles.zig");

const Block = @import("nodes/Block.zig");
const Text = @import("nodes/Text.zig");

pub const Error = error{
    UnexpectedText,
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

pub fn elementToNode(allocator: std.mem.Allocator, element: parser.Element) anyerror!Node {
    switch (element) {
        .tag => |tag| {
            return try Node.fromTag(allocator, tag);
        },
        .text => {
            return Error.UnexpectedText;
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
            .text => return .{ .text = try Text.fromTag(allocator, tag) },
        }
    }
};

pub const Common = struct {
    id: ?u32 = null,
    background_color: styles.Color = .{ .handle = .{ .r = 0, .g = 0, .b = 0, .a = 255 } },
    margin: styles.Margin = .{},
    width: styles.Size = .auto,
    height: styles.Size = .auto,

    pub fn fromAttributes(attributes: parser.Attributes) !Common {
        var common = Common{};

        if (attributes.get("id")) |id| {
            common.id = try std.fmt.parseInt(u32, id, 10);
        }
        if (attributes.get("background_color")) |bg| {
            common.background_color = try .fromString(bg);
        }
        if (attributes.get("margin")) |margin| {
            common.margin = try .fromString(margin);
        }
        if (attributes.get("width")) |width| {
            common.width = try .fromString(width);
        }
        if (attributes.get("height")) |height| {
            common.height = try .fromString(height);
        }

        return common;
    }
};

test "a tree is generated for the most basic empty block element" {
    const document = try parser.parse(std.testing.allocator, "<block></block>");
    defer document.deinit();
    const tree = try fromDocument(std.testing.allocator, document);
    defer tree.deinit();

    try std.testing.expectEqual(1, tree.root.children.items.len);
    const node = tree.root.children.items[0];

    try std.testing.expectEqual(node.block.children.items.len, 0);
}

test "a block containing a basic text" {
    const document = try parser.parse(std.testing.allocator, "<block><text>hello, world!</text></block>");
    defer document.deinit();
    const tree = try fromDocument(std.testing.allocator, document);
    defer tree.deinit();

    try std.testing.expectEqual(1, tree.root.children.items.len);
    const block = tree.root.children.items[0].block;

    try std.testing.expectEqual(block.children.items.len, 1);
    const text = block.children.items[0].text;

    try std.testing.expectEqual(text.parts.items.len, 1);
    const text_part = text.parts.items[0];

    try std.testing.expectEqualStrings("hello, world!", text_part.content);
    try std.testing.expectEqual(Text.Format{}, text_part.format);
}

test "a text node with formatting is correctly applied" {
    const document_text = "<text>The quick <b>brown</b> fox <u><i>jumped</i> over the </u> <s>lazy</s> dog!</text>";
    const document = try parser.parse(std.testing.allocator, document_text);
    defer document.deinit();
    const tree = try fromDocument(std.testing.allocator, document);
    defer tree.deinit();

    try std.testing.expectEqual(1, tree.root.children.items.len);
    const text = tree.root.children.items[0].text;

    try std.testing.expectEqual(7, text.parts.items.len);

    const parts = text.parts.items;
    try std.testing.expectEqualStrings("The quick", parts[0].content);
    try std.testing.expectEqual(Text.Format{}, parts[0].format);

    try std.testing.expectEqualStrings("brown", parts[1].content);
    try std.testing.expectEqual(Text.Format{ .bold = true }, parts[1].format);

    try std.testing.expectEqualStrings("fox", parts[2].content);
    try std.testing.expectEqual(Text.Format{}, parts[2].format);

    try std.testing.expectEqualStrings("jumped", parts[3].content);
    try std.testing.expectEqual(Text.Format{ .underline = true, .italic = true }, parts[3].format);

    try std.testing.expectEqualStrings("over the", parts[4].content);
    try std.testing.expectEqual(Text.Format{ .underline = true }, parts[4].format);

    try std.testing.expectEqualStrings("lazy", parts[5].content);
    try std.testing.expectEqual(Text.Format{ .strike_through = true }, parts[5].format);

    try std.testing.expectEqualStrings("dog!", parts[6].content);
    try std.testing.expectEqual(Text.Format{}, parts[6].format);
}

test "element attributes popular the common Node data" {
    const document = try parser.parse(std.testing.allocator, "<block id=\"100\" width=\"auto\" height=\"200px\" margin=\"300px auto\" background_color=\"#02140C\" />");
    defer document.deinit();
    const tree = try fromDocument(std.testing.allocator, document);
    defer tree.deinit();

    const block = tree.root.children.items[0].block;
    try std.testing.expectEqual(100, block.common.id);
    try std.testing.expectEqual(.auto, block.common.width);
    try std.testing.expectEqual(200, block.common.height.px);

    try std.testing.expectEqual(300, block.common.margin.top.px);
    try std.testing.expectEqual(300, block.common.margin.bottom.px);
    try std.testing.expectEqual(.auto, block.common.margin.left);
    try std.testing.expectEqual(.auto, block.common.margin.right);

    try std.testing.expectEqual(2, block.common.background_color.handle.r);
    try std.testing.expectEqual(20, block.common.background_color.handle.g);
    try std.testing.expectEqual(12, block.common.background_color.handle.b);
    try std.testing.expectEqual(255, block.common.background_color.handle.a);
}
