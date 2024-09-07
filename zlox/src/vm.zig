const std = @import("std");
const Allocator = std.mem.Allocator;

const config = @import("config");
const util = @import("./util.zig");
const debug = @import("./debug.zig");
const compiler = @import("./compiler.zig");
const value = @import("./value.zig");
const Value = value.Value;
const ValueType = value.ValueType;
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

const ArithmeticOperator = enum(u8) {
    ADD,
    SUBTRACT,
    MULTIPLY,
    DIVIDE,
    GREATER,
    LESS,
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

    pub fn runtimeError(comptime format: []const u8, args: anytype) void {
        util.printf(format, args) catch @panic("Error with printf");
        util.printf("\n", .{}) catch @panic("Error with printf");

        const inst_idx: usize = @intFromPtr(instance.ip) - @intFromPtr(instance.chunk.code.items.ptr) - 1;
        const line = instance.chunk.lines.items[inst_idx];
        util.printf("[line {d}] in script\n", .{line}) catch @panic("Error with printf");
        resetStack();
    }

    pub fn push(val: Value) void {
        instance.stackTop.* = val;
        instance.stackTop = @ptrFromInt(@intFromPtr(instance.stackTop) + @sizeOf(Value));
    }

    pub fn pop() Value {
        instance.stackTop = @ptrFromInt(@intFromPtr(instance.stackTop) - @sizeOf(Value));
        return instance.stackTop.*;
    }

    pub fn peek(distance: u8) Value {
        const target: *Value = @ptrFromInt(@intFromPtr(instance.stackTop) - (@sizeOf(Value) * (1 + distance)));
        return target.*;
    }

    pub fn is_falsey(val: Value) bool {
        return val.is_nil() or (val.is_a(.BOOLEAN) and !val.BOOLEAN);
        // switch (val) {
        //     .NIL => return true,
        //     .BOOLEAN => |b| return !b,
        //     else => return false,
        // }
    }

    pub fn interpret(allocator: Allocator, src: []const u8) !InterpretResult {
        var c = try Chunk.init(allocator);
        defer c.deinit();

        var comp = compiler.Compiler.init(src);

        if (!comp.compile(allocator, &c)) {
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
    inline fn binary_op(vt: ValueType, op: ArithmeticOperator) bool {
        if (!peek(0).is_a(vt) or !peek(1).is_a(vt)) {
            runtimeError("Operands must be numbers.", .{});
            return false;
        }
        const b = pop();
        const a = pop();
        switch (op) {
            .ADD => push(Value.NumberValue(a.NUMBER + b.NUMBER)),
            .SUBTRACT => push(Value.NumberValue(a.NUMBER - b.NUMBER)),
            .MULTIPLY => push(Value.NumberValue(a.NUMBER * b.NUMBER)),
            .DIVIDE => push(Value.NumberValue(a.NUMBER / b.NUMBER)),
            .GREATER => push(Value.BooleanValue(a.NUMBER > b.NUMBER)),
            .LESS => push(Value.BooleanValue(a.NUMBER < b.NUMBER)),
        }
        // const b: f64 = switch (pop()) {
        //     .NUMBER => |n| n,
        //     else => unreachable,
        // };
        // const a: f64 = switch (pop()) {
        //     .NUMBER => |n| n,
        //     else => unreachable,
        // };
        // switch (op) {
        //     .ADD => push(Value.NumberValue(a + b)),
        //     .SUBTRACT => push(Value.NumberValue(a - b)),
        //     .MULTIPLY => push(Value.NumberValue(a * b)),
        //     .DIVIDE => push(Value.NumberValue(a / b)),
        //     .GREATER => push(Value.BooleanValue(a > b)),
        //     .LESS => push(Value.BooleanValue(a < b)),
        // }
        return true;
    }

    pub fn run() !InterpretResult {
        while (true) {
            if (config.@"debug-trace-execution") {
                try util.printf("          ", .{});
                var slot = &instance.stack.ptr[0];
                while (@intFromPtr(slot) < @intFromPtr(instance.stackTop)) {
                    try util.printf("[ ", .{});
                    try value.print_value(slot.*);
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
                .CONSTANT => {
                    const constant: *value.Value = read_constant();
                    push(constant.*);
                },
                .NIL => push(Value.NilValue()),
                .TRUE => push(Value.BooleanValue(true)),
                .FALSE => push(Value.BooleanValue(false)),
                .EQUAL => {
                    const b = pop();
                    const a = pop();
                    push(Value.BooleanValue(a.equals(b)));
                },
                .GREATER => if (!binary_op(.NUMBER, .GREATER)) return InterpretResult.INTERPRET_RUNTIME_ERROR,
                .LESS => if (!binary_op(.NUMBER, .LESS)) return InterpretResult.INTERPRET_RUNTIME_ERROR,
                .ADD => if (!binary_op(.NUMBER, .ADD)) return InterpretResult.INTERPRET_RUNTIME_ERROR,
                .SUBTRACT => if (!binary_op(.NUMBER, .SUBTRACT)) return InterpretResult.INTERPRET_RUNTIME_ERROR,
                .MULTIPLY => if (!binary_op(.NUMBER, .MULTIPLY)) return InterpretResult.INTERPRET_RUNTIME_ERROR,
                .DIVIDE => if (!binary_op(.NUMBER, .DIVIDE)) return InterpretResult.INTERPRET_RUNTIME_ERROR,
                .NOT => push(Value.BooleanValue(is_falsey(pop()))),
                .NEGATE => {
                    // not popping and *then* validating because the book
                    //   says it's important to leave the stack intact?
                    // TBD
                    if (!peek(0).is_a(.NUMBER)) {
                        runtimeError("Operand must be a number.", .{});
                        return InterpretResult.INTERPRET_RUNTIME_ERROR;
                    }
                    push(Value.NumberValue(-(pop().NUMBER)));
                    // const val = pop();
                    // switch (val) {
                    //     .NUMBER => |n| push(Value.NumberValue(-n)),
                    //     else => unreachable,
                    // }
                },
                .RETURN => {
                    try value.print_value(pop());
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
