const std = @import("std");
const gesso = @import("gesso");

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;

    const document = "<block background_color=\"#2255ff\" width=\"400px\" height=\"200px\" /><block  background_color=\"#8800ee\" width=\"500px\" height=\"300px\" />";
    var instance = try gesso.init(gpa, "Gesso", 1280, 720, document);
    defer instance.deinit();

    while (try instance.handleInput(gpa)) {}
}
