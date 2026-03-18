const std = @import("std");
const gesso = @import("gesso");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var instance = try gesso.init("Gesso", 1280, 720);
    defer instance.deinit();

    while (try instance.handleInput(allocator)) {}
}
