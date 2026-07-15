const std = @import("std");
const gesso = @import("gesso");

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;

    const document = "<text>Hello, world!</text>";
    var instance = try gesso.init(gpa, "Gesso", 1280, 720, document);
    defer instance.deinit();

    while (try instance.handleInput(gpa)) {}
}
