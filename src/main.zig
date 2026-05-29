const std = @import("std");
const gesso = @import("gesso");

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;

    var instance = try gesso.init("Gesso", 1280, 720);
    defer instance.deinit();

    while (try instance.handleInput(gpa)) {}
}
