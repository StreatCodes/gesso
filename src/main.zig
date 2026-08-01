const std = @import("std");
const gesso = @import("gesso");

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;

    const document =
        \\<block>
        \\  <block background_color="#2255ff" width="400px" height="200px" />
        \\  <block background_color="#8800ee" padding="20px" width="500px" height="300px">
        \\    <text background_color="#ff9922">The quick brown fox jumped over the lazy dog</text>
        \\  </block>
        \\</block>
    ;

    var instance = try gesso.init(gpa, "Gesso", 1280, 720, document);
    defer instance.deinit();

    while (try instance.handleInput(gpa)) {}
}
