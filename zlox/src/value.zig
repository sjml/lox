const std = @import("std");

const List = @import("./list.zig").List;
const util = @import("./util.zig");
const Object = @import("./object.zig").Object;

pub const ValueType = enum(u8) {
    NIL,
    BOOLEAN,
    NUMBER,
    // OBJECT,
};

pub const Value = union(ValueType) {
    NIL,
    BOOLEAN: bool,
    NUMBER: f64,
    // OBJECT: *Object,

    pub inline fn BooleanValue(val: bool) Value {
        return Value{ .BOOLEAN = val };
    }
    pub inline fn NumberValue(val: f64) Value {
        return Value{ .NUMBER = val };
    }
    pub inline fn NilValue() Value {
        return Value.NIL;
    }
    // pub inline fn ObjectValue(val: *Object) Value {
    //     return Value{ .OBJECT = val };
    // }
    pub inline fn is_nil(self: Value) bool {
        return self == Value.NIL;
    }
    pub inline fn is_a(self: Value, value_type: ValueType) bool {
        return @as(ValueType, self) == value_type;
    }
    pub inline fn equals(self: Value, other: Value) bool {
        switch (self) {
            .NIL => return other == .NIL,
            .BOOLEAN => return other == .BOOLEAN and self.BOOLEAN == other.BOOLEAN,
            .NUMBER => return other == .NUMBER and self.NUMBER == other.NUMBER,
            // .BOOLEAN => |sb| return switch (other) {
            //     .BOOLEAN => |ob| return sb == ob,
            //     else => false,
            // },
            // .NUMBER => |sn| return switch (other) {
            //     .NUMBER => |on| return sn == on,
            //     else => false,
            // },
            // .OBJECT => |so| return switch (other) {
            //     .OBJECT => |oo| so.equals(oo),
            //     else => false,
            // },
        }
    }
};

pub const ValueArray = List(Value);

pub fn print_value(val: Value) !void {
    switch (val) {
        .BOOLEAN => try util.printf("{s}", .{if (val.BOOLEAN) "true" else "false"}),
        .NIL => try util.printf("nil", .{}),
        .NUMBER => try util.printf("{d}", .{val.NUMBER}),
        // .BOOLEAN => |b| try util.printf("{s}", .{if (b) "true" else "false"}),
        // .NIL => try util.printf("nil", .{}),
        // .NUMBER => |num| try util.printf("{d}", .{num}),
        // .OBJECT => |obj| try obj.print(),
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
    try std.testing.expect(n.is_nil());

    try std.testing.expect(!f.is_nil());
    try std.testing.expect(!i.is_nil());
    try std.testing.expect(!bt.is_nil());
    try std.testing.expect(!bf.is_nil());
}
