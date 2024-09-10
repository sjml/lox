module compiler;

import std.stdio;

import scanner : Scanner, Token, TokenType;

struct Compiler{
    Scanner scanner;

    void compile(string source) {
        scanner.setup(source);

        size_t line = 0;
        while (true) {
            Token tok = scanner.scanToken();
            if (tok.line != line) {
                writef("%4d ", tok.line);
                line = tok.line;
            }
            else {
                writef("   | ");
            }
            writefln("%s '%s'", tok.type, tok.start[0..tok.length]);

            if (tok.type == TokenType.EndOfFile) {
                break;
            }
        }
    }
}

