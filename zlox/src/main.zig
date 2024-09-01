const std = @import("std");

const chunk = @import("./chunk.zig");
const debug = @import("./debug.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var c = try chunk.Chunk.init(allocator);
    const constant = c.addConstant(1.2);
    c.write(@intFromEnum(chunk.OpCode.OP_CONSTANT), 123);
    c.write(@truncate(constant), 123);
    c.write(@intFromEnum(chunk.OpCode.OP_RETURN), 123);
    try debug.disassembleChunk(&c, "test chunk");
    try c.free();
}
