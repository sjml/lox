const std = @import("std");

const chunk = @import("./chunk.zig");
const VM = @import("./vm.zig").VM;
const debug = @import("./debug.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    VM.setup(allocator);

    var c = try chunk.Chunk.init(allocator);
    var constant = c.addConstant(1.2);
    c.write(@intFromEnum(chunk.OpCode.OP_CONSTANT), 123);
    c.write(@truncate(constant), 123);

    constant = c.addConstant(3.4);
    c.write(@intFromEnum(chunk.OpCode.OP_CONSTANT), 123);
    c.write(@truncate(constant), 123);

    c.write(@intFromEnum(chunk.OpCode.OP_ADD), 123);

    constant = c.addConstant(5.6);
    c.write(@intFromEnum(chunk.OpCode.OP_CONSTANT), 123);
    c.write(@truncate(constant), 123);

    c.write(@intFromEnum(chunk.OpCode.OP_DIVIDE), 123);

    c.write(@intFromEnum(chunk.OpCode.OP_NEGATE), 123);
    c.write(@intFromEnum(chunk.OpCode.OP_RETURN), 123);
    _ = VM.interpret(&c);
    c.deinit();

    VM.teardown();
}
