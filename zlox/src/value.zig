const std = @import("std");

const List = @import("./list.zig").List;
const util = @import("./util.zig");

pub const ValueType = enum(u8) {
    NIL,
    BOOLEAN,
    NUMBER,
};

pub const Value = union(ValueType) {
    NIL,
    BOOLEAN: bool,
    NUMBER: f64,

    pub inline fn BooleanValue(val: bool) Value {
        return Value{ .BOOLEAN = val };
    }
    pub inline fn NumberValue(val: f64) Value {
        return Value{ .NUMBER = val };
    }
    pub inline fn NilValue() Value {
        return Value.NIL;
    }
    pub inline fn isNil(self: Value) bool {
        return self == Value.NIL;
    }
    pub inline fn isA(self: Value, value_type: ValueType) bool {
        return @as(ValueType, self) == value_type;
    }
    pub inline fn equals(self: Value, other: Value) bool {
        switch (self) {
            .NIL => return other == .NIL,
            .BOOLEAN => return other == .BOOLEAN and self.BOOLEAN == other.BOOLEAN,
            .NUMBER => return other == .NUMBER and self.NUMBER == other.NUMBER,
        }
    }
};

pub const ValueArray = List(Value);

pub fn printValue(val: Value) !void {
    switch (val) {
        .BOOLEAN => try util.printf("{s}", .{if (val.BOOLEAN) "true" else "false"}),
        .NIL => try util.printf("nil", .{}),
        .NUMBER => try util.printf("{d}", .{val.NUMBER}),
    }
}

test "basic value types" {
    const f = Value.NumberValue(3.14);
    const i = Value.NumberValue(42);
    const bt = Value.BooleanValue(true);
    const bf = Value.BooleanValue(false);
    const n = Value.NilValue();

    try std.testing.expect(f.NUMBER == 3.14);
    try std.testing.expect(i.NUMBER == 42);
    try std.testing.expect(bt.BOOLEAN == true);
    try std.testing.expect(bf.BOOLEAN == false);
    try std.testing.expect(n.isNil());

    try std.testing.expect(!f.isNil());
    try std.testing.expect(!i.isNil());
    try std.testing.expect(!bt.isNil());
    try std.testing.expect(!bf.isNil());
}
