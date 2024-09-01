const List = @import("./list.zig").List;
const util = @import("./util.zig");

pub const Value = f64;

pub const ValueArray = List(Value);

pub fn printValue(val: Value) !void {
    try util.printf("{d}", .{val});
}
