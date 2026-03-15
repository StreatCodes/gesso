const std = @import("std");
const gesso = @import("gesso");

pub fn main() !void {
    var instance = try gesso.init(1280, 720);
    defer instance.deinit();

    while (try instance.handleInput()) {}
}
