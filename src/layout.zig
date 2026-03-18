const std = @import("std");
const sdl3 = @import("sdl3");
const styles = @import("styles.zig");
const Element = @import("Element.zig");

const LayoutBox = struct {
    rect: sdl3.rect.FRect,
    background_color: styles.Color,
};

const Layout = struct {
    boxes: std.ArrayList(LayoutBox) = .empty,
    cursor: sdl3.rect.FPoint = .{ .x = 0, .y = 0 },

    pub fn flatten(layout: *Layout, allocator: std.mem.Allocator, element: Element, parent_width: f32) !void {
        const starting_cursor = layout.cursor;
        const width: f32 = switch (element.width) {
            .px => |px| @as(f32, @floatFromInt(px)),
            .auto => parent_width,
        };
        const box = LayoutBox{
            .rect = .{ .x = layout.cursor.x, .y = layout.cursor.y, .w = width, .h = undefined },
            .background_color = element.background_color,
        };

        try layout.boxes.append(allocator, box);
        const current_index = layout.boxes.items.len - 1;

        for (element.data.block.children) |child| {
            try layout.flatten(allocator, child, width);
        }

        //TODO we can probably set a scrollable flag here if the children height is greater than explicit height
        // Calculate the height of this box now that we've flattened the children
        const height = switch (element.height) {
            .px => |px| @as(f32, @floatFromInt(px)),
            .auto => layout.cursor.y - starting_cursor.y,
        };
        layout.boxes.items[current_index].rect.h = height;
        layout.cursor.y = starting_cursor.y + height;
    }
};

pub fn flatten(allocator: std.mem.Allocator, element: Element, parent_width: f32) ![]LayoutBox {
    var layout = Layout{};
    try layout.flatten(allocator, element, parent_width);
    return layout.boxes.toOwnedSlice(allocator);
}
