const std = @import("std");

const config = @import("config");
const util = @import("./util.zig");
const debug = @import("./debug.zig");
const scanner = @import("./scanner.zig");
const Scanner = scanner.Scanner;
const Token = scanner.Token;
const TokenType = scanner.TokenType;
const chunk = @import("./chunk.zig");
const Chunk = chunk.Chunk;
const OpCode = chunk.OpCode;
const Value = @import("./value.zig").Value;

const Parser = struct {
    current: Token = undefined,
    previous: Token = undefined,
    hadError: bool,
    panicMode: bool,
};

const Precedence = enum(u8) {
    NONE,
    ASSIGNMENT,
    OR,
    AND,
    EQUALITY,
    COMPARISON,
    TERM,
    FACTOR,
    UNARY,
    CALL,
    PRIMARY,
};

const ParseFn = *const fn (*Compiler) void;
const ParseRule = struct {
    prefix: ?ParseFn,
    infix: ?ParseFn,
    precedence: Precedence,
};

const rules: []const ParseRule = &.{
    .{ .prefix = Compiler.grouping, .infix = null, .precedence = .NONE }, // LEFT_PAREN
    .{ .prefix = null, .infix = null, .precedence = .NONE }, // RIGHT_PAREN
    .{ .prefix = null, .infix = null, .precedence = .NONE }, // LEFT_BRACE
    .{ .prefix = null, .infix = null, .precedence = .NONE }, // RIGHT_BRACE
    .{ .prefix = null, .infix = null, .precedence = .NONE }, // COMMA
    .{ .prefix = null, .infix = null, .precedence = .NONE }, // DOT
    .{ .prefix = Compiler.unary, .infix = Compiler.binary, .precedence = .TERM }, // MINUS
    .{ .prefix = null, .infix = Compiler.binary, .precedence = .TERM }, // PLUS
    .{ .prefix = null, .infix = null, .precedence = .NONE }, // SEMICOLON
    .{ .prefix = null, .infix = Compiler.binary, .precedence = .FACTOR }, // SLASH
    .{ .prefix = null, .infix = Compiler.binary, .precedence = .FACTOR }, // STAR
    .{ .prefix = Compiler.unary, .infix = null, .precedence = .NONE }, // BANG
    .{ .prefix = null, .infix = Compiler.binary, .precedence = .EQUALITY }, // BANG_EQUAL
    .{ .prefix = null, .infix = null, .precedence = .NONE }, // EQUAL
    .{ .prefix = null, .infix = Compiler.binary, .precedence = .EQUALITY }, // EQUAL_EQUAL
    .{ .prefix = null, .infix = Compiler.binary, .precedence = .COMPARISON }, // GREATER
    .{ .prefix = null, .infix = Compiler.binary, .precedence = .COMPARISON }, // GREATER_EQUAL
    .{ .prefix = null, .infix = Compiler.binary, .precedence = .COMPARISON }, // LESS
    .{ .prefix = null, .infix = Compiler.binary, .precedence = .COMPARISON }, // LESS_EQUAL
    .{ .prefix = null, .infix = null, .precedence = .NONE }, // IDENTIFIER
    .{ .prefix = null, .infix = null, .precedence = .NONE }, // STRING
    .{ .prefix = Compiler.number, .infix = null, .precedence = .NONE }, // NUMBER
    .{ .prefix = null, .infix = null, .precedence = .NONE }, // AND
    .{ .prefix = null, .infix = null, .precedence = .NONE }, // CLASS
    .{ .prefix = null, .infix = null, .precedence = .NONE }, // ELSE
    .{ .prefix = Compiler.literal, .infix = null, .precedence = .NONE }, // FALSE
    .{ .prefix = null, .infix = null, .precedence = .NONE }, // FOR
    .{ .prefix = null, .infix = null, .precedence = .NONE }, // FUN
    .{ .prefix = null, .infix = null, .precedence = .NONE }, // IF
    .{ .prefix = Compiler.literal, .infix = null, .precedence = .NONE }, // NIL
    .{ .prefix = null, .infix = null, .precedence = .NONE }, // OR
    .{ .prefix = null, .infix = null, .precedence = .NONE }, // PRINT
    .{ .prefix = null, .infix = null, .precedence = .NONE }, // RETURN
    .{ .prefix = null, .infix = null, .precedence = .NONE }, // SUPER
    .{ .prefix = null, .infix = null, .precedence = .NONE }, // THIS
    .{ .prefix = Compiler.literal, .infix = null, .precedence = .NONE }, // TRUE
    .{ .prefix = null, .infix = null, .precedence = .NONE }, // VAR
    .{ .prefix = null, .infix = null, .precedence = .NONE }, // WHILE
    .{ .prefix = null, .infix = null, .precedence = .NONE }, // ERROR
    .{ .prefix = null, .infix = null, .precedence = .NONE }, // EOF
};

pub const Compiler = struct {
    parser: Parser,
    sc: Scanner,
    compilingChunk: *Chunk,

    pub fn init(src: []const u8) Compiler {
        return Compiler{
            .sc = Scanner.init(src),
            .parser = Parser{ .hadError = false, .panicMode = false },
            .compilingChunk = undefined,
        };
    }

    pub fn compile(self: *Compiler, ch: *Chunk) bool {
        self.compilingChunk = ch;
        self.advance();
        self.expression();
        self.consume(.EOF, "Expect end of expression.");
        self.endCompiler();
        return !self.parser.hadError;
    }

    fn currentChunk(self: *Compiler) *Chunk {
        return self.compilingChunk;
    }

    fn advance(self: *Compiler) void {
        self.parser.previous = self.parser.current;

        while (true) {
            self.parser.current = self.sc.scanToken();
            if (self.parser.current.toktype != .ERROR) break;

            self.errorAtCurrent(self.parser.current.lexeme);
        }
    }

    fn consume(self: *Compiler, toktype: TokenType, msg: []const u8) void {
        if (self.parser.current.toktype == toktype) {
            self.advance();
            return;
        }
        self.errorAtCurrent(msg);
    }

    fn expression(self: *Compiler) void {
        self.parsePrecedence(.ASSIGNMENT);
    }

    fn emitByte(self: *Compiler, byte: u8) void {
        self.currentChunk().write(byte, self.parser.previous.line);
    }

    fn emitBytes(self: *Compiler, b1: u8, b2: u8) void {
        self.emitByte(b1);
        self.emitByte(b2);
    }

    fn emitReturn(self: *Compiler) void {
        self.emitByte(@intFromEnum(OpCode.RETURN));
    }

    fn emitConstant(self: *Compiler, val: Value) void {
        self.emitBytes(@intFromEnum(OpCode.CONSTANT), self.makeConstant(val));
    }

    fn endCompiler(self: *Compiler) void {
        self.emitReturn();
        if (config.@"debug-print-code") {
            if (!self.parser.hadError) {
                debug.disassembleChunk(self.compilingChunk, "code");
            }
        }
    }

    fn number(self: *Compiler) void {
        const v: f64 = std.fmt.parseFloat(f64, self.parser.previous.lexeme) catch unreachable;
        self.emitConstant(Value.NumberValue(v));
    }

    fn unary(self: *Compiler) void {
        const op_type = self.parser.previous.toktype;
        self.parsePrecedence(.UNARY);
        switch (op_type) {
            .BANG => self.emitByte(@intFromEnum(OpCode.NOT)),
            .MINUS => self.emitByte(@intFromEnum(OpCode.NEGATE)),
            else => return,
        }
    }

    fn binary(self: *Compiler) void {
        const op_type = self.parser.previous.toktype;
        const rule = Compiler.getRule(op_type);
        const next_prec: u8 = @intFromEnum(rule.precedence) + 1;
        self.parsePrecedence(@enumFromInt(next_prec));

        switch (op_type) {
            .BANG_EQUAL => self.emitBytes(@intFromEnum(OpCode.EQUAL), @intFromEnum(OpCode.NOT)),
            .EQUAL_EQUAL => self.emitByte(@intFromEnum(OpCode.EQUAL)),
            .GREATER => self.emitByte(@intFromEnum(OpCode.GREATER)),
            .GREATER_EQUAL => self.emitBytes(@intFromEnum(OpCode.LESS), @intFromEnum(OpCode.NOT)),
            .LESS => self.emitByte(@intFromEnum(OpCode.LESS)),
            .LESS_EQUAL => self.emitBytes(@intFromEnum(OpCode.GREATER), @intFromEnum(OpCode.NOT)),
            .PLUS => self.emitByte(@intFromEnum(OpCode.ADD)),
            .MINUS => self.emitByte(@intFromEnum(OpCode.SUBTRACT)),
            .STAR => self.emitByte(@intFromEnum(OpCode.MULTIPLY)),
            .SLASH => self.emitByte(@intFromEnum(OpCode.DIVIDE)),
            else => unreachable,
        }
    }

    fn literal(self: *Compiler) void {
        switch (self.parser.previous.toktype) {
            .FALSE => self.emitByte(@intFromEnum(OpCode.FALSE)),
            .NIL => self.emitByte(@intFromEnum(OpCode.NIL)),
            .TRUE => self.emitByte(@intFromEnum(OpCode.TRUE)),
            else => unreachable,
        }
    }

    fn parsePrecedence(self: *Compiler, precedence: Precedence) void {
        self.advance();
        const prefixRule = Compiler.getRule(self.parser.previous.toktype).prefix;
        if (prefixRule == null) {
            self.err("Expect expression.");
            return;
        }
        prefixRule.?(self);
        while (@intFromEnum(precedence) <= @intFromEnum(Compiler.getRule(self.parser.current.toktype).precedence)) {
            self.advance();
            const infixRule = Compiler.getRule(self.parser.previous.toktype).infix;
            infixRule.?(self);
        }
    }

    fn getRule(toktype: TokenType) *const ParseRule {
        return &rules[@intFromEnum(toktype)];
    }

    fn grouping(self: *Compiler) void {
        self.expression();
        self.consume(.RIGHT_PAREN, "Expect ')' after expression.");
    }

    fn makeConstant(self: *Compiler, val: Value) u8 {
        const constant = self.compilingChunk.addConstant(val);
        if (constant > std.math.maxInt(u8)) {
            self.err("Too many constants in one chunk.");
            return 0;
        }
        return @truncate(constant);
    }

    fn errorAtCurrent(self: *Compiler, msg: []const u8) void {
        self.errorAt(&self.parser.current, msg);
    }

    fn err(self: *Compiler, msg: []const u8) void {
        self.errorAt(&self.parser.previous, msg);
    }

    fn errorAt(self: *Compiler, token: *Token, msg: []const u8) void {
        if (self.parser.panicMode) return;
        self.parser.panicMode = true;
        util.printf("[line {d}] Error", .{token.line}) catch @panic("Error with printf");
        switch (token.toktype) {
            .EOF => util.printf(" at end", .{}) catch @panic("Error with printf"),
            .ERROR => {},
            else => util.printf(" at '{s}'", .{token.lexeme}) catch @panic("Error with printf"),
        }
        util.printf(": {s}\r\n", .{msg}) catch @panic("Error with printf");
        self.parser.hadError = true;
    }
};
