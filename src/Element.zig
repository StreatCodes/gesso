const styles = @import("styles.zig");

const Element = @This();

id: u32 = 0, //TODO not sure about this default yet
background_color: styles.Color,
margin: styles.Margin = .{},
width: styles.Size = .auto,
height: styles.Size = .auto,

data: Data,

pub const Data = union(enum) {
    block: struct { children: []Element },
    text: struct { content: []const u8 },
    input: struct { placeholder: ?[]const u8, value: []const u8 },
};
