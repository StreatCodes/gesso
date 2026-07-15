const std = @import("std");
const Self = @This();

slice: []const u8,
offset: usize = 0,

pub fn init(slice: []const u8) Self {
    return Self{
        .slice = slice,
    };
}

pub fn get(self: *Self) ?u8 {
    if (self.offset >= self.slice.len)
        return null;
    const c = self.slice[self.offset];
    self.offset += 1;
    return c;
}

pub fn peek(self: Self) ?u8 {
    if (self.offset >= self.slice.len)
        return null;
    return self.slice[self.offset];
}

pub fn peekSlice(self: Self, count: usize) []const u8 {
    const end = @min(self.offset + count, self.slice.len);
    return self.slice[self.offset..end];
}

/// Consumes the given character if it matches the next one in the slice, otherwise
/// returns null.
pub fn must(self: *Self, char: u8) ?void {
    if (self.offset >= self.slice.len) return null;

    const c = self.slice[self.offset];
    if (c != char) return null;

    self.offset += 1;
}

pub fn mustSlice(self: *Self, string: []const u8) ?void {
    if (self.offset >= self.slice.len) return null;

    for (string) |char| {
        const c = self.slice[self.offset];
        if (c != char) return null;

        self.offset += 1;
    }
}

pub fn readWhile(self: *Self, comptime predicate: fn (u8) bool) []const u8 {
    const start = self.offset;
    var end = start;
    while (end < self.slice.len and predicate(self.slice[end])) {
        end += 1;
    }
    self.offset = end;
    return self.slice[start..end];
}

pub fn readUntil(self: *Self, comptime predicate: fn (u8) bool) []const u8 {
    const start = self.offset;
    var end = start;
    while (end < self.slice.len and !predicate(self.slice[end])) {
        end += 1;
    }
    self.offset = end;
    return self.slice[start..end];
}

/// Reads until the scalar. The returned slice excludes the scalar.
/// The new offset will be the index of the scalar
pub fn readUntilScalar(self: *Self, scalar: u8) []const u8 {
    const start = self.offset;
    var end = start;
    while (end < self.slice.len and self.slice[end] != scalar) {
        end += 1;
    }
    self.offset = end;
    return self.slice[start..end];
}

/// Reads until the scalar. The returned slice excludes the scalar.
/// The new offset will be the index after the scalar
pub fn readUntilScalarExcluding(self: *Self, scalar: u8) []const u8 {
    const result = self.readUntilScalar(scalar);
    if (self.offset < self.slice.len) self.offset += 1;
    return result;
}

/// Reads until the scalar. The returned slice includes the scalar.
/// The new offset will be the index after the scalar
pub fn readUntilScalarConsuming(self: *Self, scalar: u8) []const u8 {
    const start = self.offset;
    _ = self.readUntilScalar(scalar);
    if (self.offset < self.slice.len) self.offset += 1;
    return self.slice[start..self.offset];
}
