const std = @import("std");
const Allocator = std.mem.Allocator;

const config = @import("config");
const util = @import("./util.zig");
const debug = @import("./debug.zig");
const compiler = @import("./compiler.zig");
const value = @import("./value.zig");
const Value = value.Value;
const List = @import("./list.zig").List;
const chunk = @import("./chunk.zig");
const Chunk = chunk.Chunk;
const OpCode = chunk.OpCode;

const STACK_MAX = 256;

pub const InterpretResult = enum(u8) {
    INTERPRET_OK,
    INTERPRET_COMPILE_ERROR,
    INTERPRET_RUNTIME_ERROR,
};

pub const VM = struct {
    var instance: VM = undefined;
    chunk: *Chunk = undefined,
    ip: [*]u8 = undefined,
    stack: []Value = undefined,
    stackTop: *Value = undefined,

    pub fn setup(allocator: Allocator) void {
        instance = .{ .stack = allocator.alloc(Value, STACK_MAX) catch @panic("Error allocating memory.") };
        resetStack();
    }

    pub fn teardown() void {}

    pub fn resetStack() void {
        instance.stackTop = &instance.stack[0];
    }

    pub fn push(val: Value) void {
        instance.stackTop.* = val;
        instance.stackTop = @ptrFromInt(@intFromPtr(instance.stackTop) + @sizeOf(Value));
    }

    pub fn pop() Value {
        instance.stackTop = @ptrFromInt(@intFromPtr(instance.stackTop) - @sizeOf(Value));
        return instance.stackTop.*;
    }

    pub fn interpret(allocator: Allocator, src: []const u8) !InterpretResult {
        var c = try Chunk.init(allocator);
        defer c.deinit();

        var comp = compiler.Compiler.init(src);

        if (!comp.compile(&c)) {
            return .INTERPRET_COMPILE_ERROR;
        }

        instance.chunk = &c;
        instance.ip = instance.chunk.code.items.ptr;

        return run();
    }

    // these are macros in canonical clox;
    //   not sure the best way to zigify them,
    //   but here's a shot at it.
    inline fn read_byte() *u8 {
        const ret = &instance.ip[0];
        instance.ip += 1;
        return ret;
    }
    inline fn read_constant() *Value {
        return &instance.chunk.constants.items[@as(usize, read_byte().*)];
    }

    pub fn run() !InterpretResult {
        while (true) {
            if (config.@"debug-trace-execution") {
                try util.printf("          ", .{});
                var slot = &instance.stack.ptr[0];
                while (@intFromPtr(slot) < @intFromPtr(instance.stackTop)) {
                    try util.printf("[ ", .{});
                    try value.printValue(slot.*);
                    try util.printf(" ]", .{});
                    slot = @ptrFromInt(@intFromPtr(slot) + @sizeOf(Value));
                }
                try util.printf("\n", .{});

                const ptr0addr = @intFromPtr(&instance.chunk.code.items.ptr[0]);
                const ptr1addr = @intFromPtr(&instance.ip[0]);
                const offset = ptr1addr - ptr0addr;
                _ = try debug.disassembleInstruction(instance.chunk, offset);
            }
            const instruction: OpCode = @enumFromInt(read_byte().*);
            switch (instruction) {
                OpCode.CONSTANT => {
                    const constant: *value.Value = read_constant();
                    push(constant.*);
                },
                OpCode.ADD => {
                    const b = pop();
                    const a = pop();
                    push(a + b);
                },
                OpCode.SUBTRACT => {
                    const b = pop();
                    const a = pop();
                    push(a - b);
                },
                OpCode.MULTIPLY => {
                    const b = pop();
                    const a = pop();
                    push(a * b);
                },
                OpCode.DIVIDE => {
                    const b = pop();
                    const a = pop();
                    push(a / b);
                },
                OpCode.NEGATE => {
                    push(-pop());
                },
                OpCode.RETURN => {
                    try value.printValue(pop());
                    try util.printf("\r\n", .{});
                    return InterpretResult.INTERPRET_OK;
                },
                // else => {
                //     @panic("Unimplemented opcode!");
                // },
            }
        }
    }
};
