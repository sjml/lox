const std = @import("std");
const Allocator = std.mem.Allocator;

const util = @import("./util.zig");

pub const ObjectType = enum(u8) {
    STRING,
};

pub const Object = struct {
    otype: ObjectType,
    allocator: Allocator,

    fn init(comptime T: type, allocator: Allocator, kind: ObjectType) *T {
        const new_obj = allocator.create(T) catch @panic("Couldn't allocate memory creating object.");
        new_obj.obj = Object{
            .otype = kind,
            .allocator = allocator,
        };
        return new_obj;
    }

    pub fn print(self: *Object) !void {
        switch (self.otype) {
            .STRING => try util.printf("{s}", self.as_string().chars),
        }
    }

    pub fn equals(self: *Object, other: *Object) bool {
        if (self.otype != other.otype) {
            return false;
        }
        switch (self.otype) {
            .STRING => {
                const a = self.as_string();
                const b = other.as_string();
                if (a.len != b.len) {
                    return false;
                }
                return std.mem.eql(u8, a.chars, b.chars);
            },
        }
    }

    pub fn as_string(self: *Object) *String {
        std.debug.assert(self.otype == .STRING);
        return @fieldParentPtr("obj", self);
    }

    pub const String = struct {
        obj: Object,
        len: usize,
        chars: []const u8,

        pub fn init(allocator: Allocator, contents: []const u8) *String {
            const new_str = Object.init(String, allocator, .STRING);
            new_str.chars = allocator.dupe(u8, contents) catch @panic("Could not allocate memory initiating string.");
            new_str.len = contents.len;
            return new_str;
        }

        pub fn destroy(self: *String) void {
            self.obj.allocator.free(self.chars);
            self.obj.allocator.destroy(self);
        }
    };
};

fn str_cmp(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) {
        return false;
    }
    return std.mem.eql(u8, a, b);
}

test "basic inheritance" {
    const allocator = std.testing.allocator;
    const s = Object.String.init(allocator, "hello there");
    try std.testing.expect(str_cmp(s.chars, "hello there"));
    var o = &s.obj;
    const s1 = o.as_string();
    try std.testing.expect(s1.len > 0);
    try std.testing.expect(str_cmp(s1.chars, "hello there"));
    s.destroy();
}
