const std = @import("std");
const tree = @import("../tree.zig");
const parser = @import("../parser.zig");

const Text = @This();

const Part = struct {
    bold: bool = false,
    underline: bool = false,
    italic: bool = false,
    strike_through: bool = false,

    content: []const u8 = "",
};

common: tree.Common = .{},
content: []const u8 = "",

pub fn fromTag(tag: parser.Tag) Text {
    std.debug.print("Found text tag {s}\n", .{tag.name});
    return .{};
}
