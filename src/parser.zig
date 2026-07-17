const std = @import("std");
const SliceReader = @import("util/SliceReader.zig");

const Error = error{
    UnexpectedToken,
    ExpectedTag,
    ExpectedClosingTag,
    ExpectedClosingBracket,
    NameRequired,
};

const Attributes = std.StringHashMap([]const u8);
pub const Tag = struct {
    name: []const u8,
    children: []Element,
    attributes: Attributes,
};

pub const Text = []const u8;

pub const Element = union(enum) {
    tag: Tag,
    text: Text,
};

//TODO the parsing could use some work to detect more malformed documents
pub fn parse(allocator: std.mem.Allocator, text: []const u8) !Document {
    var reader = SliceReader.init(text);
    var document = Document{
        .reader = &reader,
        .arena = std.heap.ArenaAllocator.init(allocator),
        .children = undefined,
    };

    const arena = document.arena.allocator();

    document.children = readChildren(arena, &reader) catch |err| {
        //TODO improve this to include more context
        // logError(reader, err);
        return err;
    };

    return document;
}

const PError = std.mem.Allocator.Error || Error;
fn logError(reader: SliceReader, message: PError) void {
    const c = if (reader.offset < reader.slice.len) reader.slice[reader.offset] else reader.slice[reader.slice.len - 1];
    std.debug.print("{}, found '{c}'\n", .{ message, c });
}

pub const Document = struct {
    reader: *SliceReader,
    arena: std.heap.ArenaAllocator,
    children: []Element,

    pub fn deinit(document: Document) void {
        document.arena.deinit();
    }
};

fn readChildren(allocator: std.mem.Allocator, reader: *SliceReader) PError![]Element {
    var children: std.ArrayList(Element) = .empty;
    while (true) {
        _ = reader.readWhile(isWhitespace);
        if (reader.offset >= reader.slice.len) break;

        const next = reader.peekSlice(2);
        if (next.len == 0) break;
        if (next.len == 2 and std.mem.eql(u8, next, "</")) break;

        if (next[0] == '<') {
            //a tag e.g. <text>
            const tag = try readTag(allocator, reader);
            try children.append(allocator, .{ .tag = tag });
        } else {
            //Text
            const text = readText(reader);
            try children.append(allocator, .{ .text = text });
        }
    }

    return try children.toOwnedSlice(allocator);
}

fn readTag(allocator: std.mem.Allocator, reader: *SliceReader) !Tag {
    reader.must('<') orelse return Error.ExpectedTag;
    const name = reader.readWhile(isName);
    if (name.len == 0) return Error.NameRequired;
    const attributes = try readAttributes(allocator, reader);

    const closing = reader.get() orelse return Error.ExpectedClosingBracket;

    // self closing tag e.g. <input />
    if (closing == '/') {
        reader.must('>') orelse return Error.ExpectedClosingBracket;
        return .{
            .name = name,
            .attributes = attributes,
            .children = &[_]Element{},
        };
    }

    if (closing == '>') {
        const children = try readChildren(allocator, reader);
        reader.mustSlice("</") orelse return Error.ExpectedClosingTag;
        reader.mustSlice(name) orelse return Error.ExpectedClosingTag;
        reader.must('>') orelse return Error.ExpectedClosingTag;

        return .{
            .name = name,
            .attributes = attributes,
            .children = children,
        };
    }

    return Error.ExpectedClosingBracket;
}

fn readAttributes(allocator: std.mem.Allocator, reader: *SliceReader) !Attributes {
    var attributes = Attributes.init(allocator);

    while (true) {
        _ = reader.readWhile(isWhitespace);
        const name = reader.readWhile(isName);
        if (name.len == 0) break;

        reader.mustSlice("=\"") orelse return Error.UnexpectedToken;
        const value = reader.readUntilScalarExcluding('"');
        try attributes.put(name, value);
    }
    return attributes;
}

fn readText(reader: *SliceReader) Text {
    const text = reader.readUntilScalar('<');
    return std.mem.trimEnd(u8, text, " \n\t");
}

fn isWhitespace(char: u8) bool {
    return char == ' ' or char == '\n' or char == '\t';
}

/// Matches Element or Attribute names which can only include lowercase letters and underscores
fn isName(char: u8) bool {
    if (char == '_') return true;
    return char >= 'a' and char <= 'z';
}

test "parsing an empty document is valid" {
    const document = try parse(std.testing.allocator, "");
    defer document.deinit();
    try std.testing.expectEqual(0, document.children.len);
}

test "can parse a basic text element" {
    const text = "<text>Hello, world!</text>";
    const document = try parse(std.testing.allocator, text);
    defer document.deinit();
    try std.testing.expectEqual(1, document.children.len);
    try std.testing.expectEqualStrings("text", document.children[0].tag.name);
    try std.testing.expectEqualStrings("Hello, world!", document.children[0].tag.children[0].text);
}

test "can parse multiple elements" {
    const text =
        \\<text>First text</text>
        \\<text>Second text</text>
    ;
    const document = try parse(std.testing.allocator, text);
    defer document.deinit();

    try std.testing.expectEqualStrings("text", document.children[0].tag.name);
    try std.testing.expectEqualStrings("First text", document.children[0].tag.children[0].text);
    try std.testing.expectEqualStrings("text", document.children[1].tag.name);
    try std.testing.expectEqualStrings("Second text", document.children[1].tag.children[0].text);
}

test "can parse self closing elements with attributes" {
    const text = "<input placeholder=\"placeholder text\" />";
    const document = try parse(std.testing.allocator, text);
    defer document.deinit();

    try std.testing.expectEqualStrings("input", document.children[0].tag.name);
    try std.testing.expectEqualStrings("placeholder text", document.children[0].tag.attributes.get("placeholder").?);
}

test "allow underscore in element and attribute names" {
    const text = "<an_element multi_word_attribute=\"attribute value!\" />";
    const document = try parse(std.testing.allocator, text);
    defer document.deinit();

    try std.testing.expectEqualStrings("an_element", document.children[0].tag.name);
    try std.testing.expectEqualStrings("attribute value!", document.children[0].tag.attributes.get("multi_word_attribute").?);
}

test "can parse nested elements" {
    const text =
        \\<box>
        \\  <text>First text</text>
        \\  <text>Second text</text>
        \\</box>
    ;
    const document = try parse(std.testing.allocator, text);
    defer document.deinit();
    try std.testing.expectEqual(1, document.children.len);
    try std.testing.expectEqualStrings("box", document.children[0].tag.name);
    const children = document.children[0].tag.children;
    try std.testing.expectEqualStrings("First text", children[0].tag.children[0].text);
    try std.testing.expectEqualStrings("Second text", children[1].tag.children[0].text);
}

test "can parse mixed text and tag elements" {
    const text = "<text>The <b>quick</b> brown fox <i>jumped</i> over the <u>lazy</u> dog!</text>";
    const document = try parse(std.testing.allocator, text);
    defer document.deinit();

    try std.testing.expectEqual(1, document.children.len);
    const text_children = document.children[0].tag.children;
    try std.testing.expectEqual(7, text_children.len);
    try std.testing.expectEqualStrings("The", text_children[0].text);
    try std.testing.expectEqualStrings("b", text_children[1].tag.name);
    try std.testing.expectEqualStrings("quick", text_children[1].tag.children[0].text);
    try std.testing.expectEqualStrings("brown fox", text_children[2].text);
    try std.testing.expectEqualStrings("jumped", text_children[3].tag.children[0].text);
    try std.testing.expectEqualStrings("over the", text_children[4].text);
    try std.testing.expectEqualStrings("lazy", text_children[5].tag.children[0].text);
    try std.testing.expectEqualStrings("dog!", text_children[6].text);
}

test "returns error an element is added with no name" {
    const text = "<></>";
    const result = parse(std.testing.allocator, text);

    try std.testing.expectError(Error.NameRequired, result);
}
