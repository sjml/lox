const std = @import("std");

const util = @import("./util.zig");
const scanner = @import("./scanner.zig");
const Scanner = scanner.Scanner;
const Token = scanner.Token;
const TokenType = scanner.TokenType;

pub fn compile(src: []const u8) void {
    var sc = Scanner.init(src);

    var line: u32 = 0;
    while (true) {
        const token = sc.scanToken();
        if (token.line != line) {
            util.printf("{d:4} ", .{token.line}) catch @panic("Problem calling printf...");
            line = token.line;
        } else {
            util.printf("   | ", .{}) catch @panic("Problem calling printf...");
        }
        util.printf("{s:<13} '{s}'\n", .{ std.enums.tagName(TokenType, token.toktype).?, token.lexeme }) catch @panic("Problem calling printf...");

        if (token.toktype == TokenType.EOF) {
            break;
        }
    }
}
