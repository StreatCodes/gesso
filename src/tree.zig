const std = @import("std");
const parser = @import("parser.zig");
const styles = @import("styles.zig");
const Quad = @import("Renderer/Quad.zig");

const Block = @import("nodes/Block.zig");
const Text = @import("nodes/Text.zig");

pub const Error = error{
    SingleChildRequired,
    UnexpectedText,
    InvalidTextChild,
    UnknownNode,
};

pub const Tree = struct {
    arena: std.heap.ArenaAllocator,
    root: Node,

    pub fn deinit(tree: Tree) void {
        tree.arena.deinit();
    }
};

pub fn fromDocument(allocator: std.mem.Allocator, document: parser.Document) !Tree {
    var tree = Tree{
        .arena = std.heap.ArenaAllocator.init(allocator),
        .root = undefined,
    };
    const arena = tree.arena.allocator();

    if (document.children.len != 1) return Error.SingleChildRequired;
    tree.root = try elementToNode(arena, document.children[0]);

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

pub const BoundingBox = struct {
    x: f32,
    y: f32,
    w: f32,
    h: ?f32 = null,

    pub fn applyPadding(box: BoundingBox, padding: styles.Padding) BoundingBox {
        var new = box;
        if (padding.left == .px) {
            new.x += padding.left.px;
            new.w -= padding.left.px;
        }
        if (padding.top == .px) {
            new.y += padding.top.px;
            if (box.h != null) new.h.? -= padding.top.px;
        }
        if (padding.right == .px) new.w -= padding.right.px;
        if (padding.bottom == .px and new.h != null) new.h.? -= padding.bottom.px;

        return new;
    }

    pub fn applySize(box: BoundingBox, width: styles.Size, height: styles.Size) BoundingBox {
        var new = box;
        switch (width) {
            .px => |px| new.w = px,
            .auto => {},
        }
        switch (height) {
            .px => |px| new.h = px,
            .auto => {},
        }

        return new;
    }
};

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

    pub fn layout(node: Node, allocator: std.mem.Allocator, bbox: BoundingBox, quads: *std.ArrayList(Quad)) std.mem.Allocator.Error!BoundingBox {
        switch (node) {
            .block => |block| return try block.layout(allocator, bbox, quads),
            .text => |text| return try text.layout(allocator, bbox, quads),
        }
    }
};

pub const Common = struct {
    id: ?u32 = null,
    background_color: styles.Color = .{ .handle = .{ .r = 0, .g = 0, .b = 0, .a = 0 } },
    padding: styles.Padding = .{},
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
        if (attributes.get("padding")) |padding| {
            common.padding = try .fromString(padding);
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

    try std.testing.expectEqual(.block, std.meta.activeTag(tree.root));
    const block = tree.root.block;

    try std.testing.expectEqual(block.children.items.len, 0);
}

test "a block containing a basic text" {
    const document = try parser.parse(std.testing.allocator, "<block><text>hello, world!</text></block>");
    defer document.deinit();
    const tree = try fromDocument(std.testing.allocator, document);
    defer tree.deinit();

    const block = tree.root.block;
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

    const text = tree.root.text;
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
    const document = try parser.parse(std.testing.allocator, "<block id=\"100\" width=\"auto\" height=\"200.5px\" padding=\"300px auto\" background_color=\"#02140C\" />");
    defer document.deinit();
    const tree = try fromDocument(std.testing.allocator, document);
    defer tree.deinit();

    const block = tree.root.block;
    try std.testing.expectEqual(100, block.common.id);
    try std.testing.expectEqual(.auto, block.common.width);
    try std.testing.expectEqual(200.5, block.common.height.px);

    try std.testing.expectEqual(300, block.common.padding.top.px);
    try std.testing.expectEqual(300, block.common.padding.bottom.px);
    try std.testing.expectEqual(.auto, block.common.padding.left);
    try std.testing.expectEqual(.auto, block.common.padding.right);

    try std.testing.expectEqual(2, block.common.background_color.handle.r);
    try std.testing.expectEqual(20, block.common.background_color.handle.g);
    try std.testing.expectEqual(12, block.common.background_color.handle.b);
    try std.testing.expectEqual(255, block.common.background_color.handle.a);
}

test "a basic block layout returns two quads" {
    const document = try parser.parse(std.testing.allocator, "<block height=\"50px\" />");
    defer document.deinit();
    const tree = try fromDocument(std.testing.allocator, document);
    defer tree.deinit();

    const box = BoundingBox{ .x = 0, .y = 0, .w = 200, .h = 200 };
    var quads: std.ArrayList(Quad) = .empty;
    defer quads.deinit(std.testing.allocator);
    _ = try tree.root.layout(std.testing.allocator, box, &quads);

    try std.testing.expectEqual(1, quads.items.len);
    try std.testing.expectEqual(Quad{ .rect = .{ .x = 0, .y = 0, .w = 200, .h = 50 } }, quads.items[0]);
}
