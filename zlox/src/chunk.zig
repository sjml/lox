const std = @import("std");
const Allocator = std.mem.Allocator;

const memory = @import("./memory.zig");
const value = @import("./value.zig");
const List = @import("./list.zig").List;
const Value = value.Value;
const ValueArray = value.ValueArray;

pub const OpCode = enum(u8) {
    OP_CONSTANT,
    OP_ADD,
    OP_SUBTRACT,
    OP_MULTIPLY,
    OP_DIVIDE,
    OP_NEGATE,
    OP_RETURN,
};

pub const Chunk = struct {
    count: usize = 0,
    allocator: Allocator,
    code: List(u8),
    lines: List(u32),
    constants: ValueArray,

    pub fn init(allocator: Allocator) !Chunk {
        return Chunk{
            .allocator = allocator,
            .code = try List(u8).init(allocator),
            .lines = try List(u32).init(allocator),
            .constants = try ValueArray.init(allocator),
        };
    }

    pub fn deinit(self: *Chunk) void {
        self.code.deinit();
        self.lines.deinit();
        self.constants.deinit();
    }

    pub fn write(self: *Chunk, byte: u8, line: u32) void {
        self.code.add(byte);
        self.lines.add(line);
        self.count += 1;
    }

    pub fn addConstant(self: *Chunk, val: Value) usize {
        self.constants.add(val);
        return self.constants.count - 1;
    }
};

test "allocate and free chunk" {
    const allocator = std.testing.allocator;
    var chunk = try Chunk.init(allocator);
    try chunk.deinit();
}

test "write chunk" {
    const allocator = std.testing.allocator;
    var chunk = try Chunk.init(allocator);
    try std.testing.expect(chunk.code.len == 0);
    try chunk.write(123);
    try std.testing.expect(chunk.code.len == 8);
    try std.testing.expect(chunk.count == 1);
    try std.testing.expect(chunk.code[0] == 123);
    try chunk.deinit();
}
