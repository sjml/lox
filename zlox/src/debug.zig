const std = @import("std");

const util = @import("./util.zig");
const Chunk = @import("./chunk.zig").Chunk;
const OpCode = @import("./chunk.zig").OpCode;
const value = @import("./value.zig");

pub fn disassembleChunk(chunk: *Chunk, name: []const u8) !void {
    try util.printf("== {s} ==\n", .{name});

    var offset: usize = 0;
    while (offset < chunk.count) {
        offset = try disassembleInstruction(chunk, offset);
    }
}

pub fn disassembleInstruction(chunk: *Chunk, offset: usize) !usize {
    try util.printf("{d:0>4} ", .{offset});
    if (offset > 0 and chunk.lines.items[offset] == chunk.lines.items[offset - 1]) {
        try util.printf("   | ", .{});
    } else {
        try util.printf("{d:4} ", .{chunk.lines.items[offset]});
    }

    const inst: OpCode = @enumFromInt(chunk.code.items[offset]);
    switch (inst) {
        OpCode.CONSTANT => return try constantInstruction("CONSTANT", chunk, offset),
        OpCode.NIL => return try simpleInstruction("NIL", offset),
        OpCode.TRUE => return try simpleInstruction("TRUE", offset),
        OpCode.FALSE => return try simpleInstruction("FALSE", offset),
        OpCode.EQUAL => return try simpleInstruction("EQUAL", offset),
        OpCode.GREATER => return try simpleInstruction("GREATER", offset),
        OpCode.LESS => return try simpleInstruction("LESS", offset),
        OpCode.ADD => return try simpleInstruction("ADD", offset),
        OpCode.SUBTRACT => return try simpleInstruction("SUBTRACT", offset),
        OpCode.MULTIPLY => return try simpleInstruction("MULTIPLY", offset),
        OpCode.DIVIDE => return try simpleInstruction("DIVIDE", offset),
        OpCode.NOT => return try simpleInstruction("NOT", offset),
        OpCode.NEGATE => return try simpleInstruction("NEGATE", offset),
        OpCode.RETURN => return try simpleInstruction("RETURN", offset),
        // else => {
        //     @panic("Unknown opcode!");
        // },
    }
}

fn simpleInstruction(name: []const u8, offset: usize) !usize {
    try util.printf("{s}\n", .{name});
    return offset + 1;
}

fn constantInstruction(name: []const u8, chunk: *Chunk, offset: usize) !usize {
    const constantIdx = chunk.code.items[offset + 1];
    try util.printf("{s: <16} {d:4} '", .{ name, constantIdx });
    try value.print_value(chunk.constants.items[constantIdx]);
    try util.printf("'\n", .{});
    return offset + 2;
}
