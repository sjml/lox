const std = @import("std");

pub const TokenType = enum(u8) {
    // Single-character tokens
    LEFT_PAREN,
    RIGHT_PAREN,
    LEFT_BRACE,
    RIGHT_BRACE,
    COMMA,
    DOT,
    MINUS,
    PLUS,
    SEMICOLON,
    SLASH,
    STAR,

    // One- or two-character tokens
    BANG,
    BANG_EQUAL,
    EQUAL,
    EQUAL_EQUAL,
    GREATER,
    GREATER_EQUAL,
    LESS,
    LESS_EQUAL,

    // Literals
    IDENTIFIER,
    STRING,
    NUMBER,

    // Keywords
    AND,
    CLASS,
    ELSE,
    FALSE,
    FOR,
    FUN,
    IF,
    NIL,
    OR,
    PRINT,
    RETURN,
    SUPER,
    THIS,
    TRUE,
    VAR,
    WHILE,

    ERROR,
    EOF,
};

pub const Token = struct {
    toktype: TokenType,
    lexeme: []const u8,
    line: u32,
};

pub const Scanner = struct {
    src: []const u8,
    start: usize,
    current: usize,
    line: u32,

    pub fn init(src: []const u8) Scanner {
        return Scanner{ .src = src, .start = 0, .current = 0, .line = 1 };
    }

    pub fn scanToken(self: *Scanner) Token {
        self.skipWhitespaceAndComments();
        self.start = self.current;
        if (self.isAtEnd()) {
            return self.makeToken(TokenType.EOF);
        }

        const c = self.advance();

        if (std.ascii.isAlphabetic(c) or c == '_') {
            return self.identifier();
        }
        if (std.ascii.isDigit(c)) {
            return self.number();
        }

        switch (c) {
            '(' => return self.makeToken(.LEFT_PAREN),
            ')' => return self.makeToken(.RIGHT_PAREN),
            '{' => return self.makeToken(.LEFT_BRACE),
            '}' => return self.makeToken(.RIGHT_BRACE),
            ';' => return self.makeToken(.SEMICOLON),
            ',' => return self.makeToken(.COMMA),
            '.' => return self.makeToken(.DOT),
            '-' => return self.makeToken(.MINUS),
            '+' => return self.makeToken(.PLUS),
            '/' => return self.makeToken(.SLASH),
            '*' => return self.makeToken(.STAR),

            '!' => return self.makeToken(if (self.match('=')) .BANG_EQUAL else .BANG),
            '=' => return self.makeToken(if (self.match('=')) .EQUAL_EQUAL else .EQUAL),
            '<' => return self.makeToken(if (self.match('=')) .LESS_EQUAL else .LESS),
            '>' => return self.makeToken(if (self.match('=')) .GREATER_EQUAL else .GREATER),

            '"' => return self.string(),

            0 => return self.makeToken(.EOF),

            else => return self.errorToken("Unexpected character."),
        }

        // return self.errorToken("Unexpected character.");
        unreachable;
    }

    fn skipWhitespaceAndComments(self: *Scanner) void {
        while (true) {
            const c = self.peek();
            switch (c) {
                ' ' => _ = self.advance(),
                '\r' => _ = self.advance(),
                '\t' => _ = self.advance(),
                '\n' => {
                    self.line += 1;
                    _ = self.advance();
                },
                '/' => {
                    if (self.peekNext() == '/') {
                        while (self.peek() != '\n' and !self.isAtEnd()) _ = self.advance();
                    } else {
                        return;
                    }
                },
                else => return,
            }
        }
    }

    fn identifier(self: *Scanner) Token {
        var c = self.peek();
        while (std.ascii.isAlphabetic(c) or std.ascii.isDigit(c) or c == '_') {
            _ = self.advance();
            c = self.peek();
        }
        return self.makeToken(self.identifierType());
    }

    fn identifierType(self: *Scanner) TokenType {
        switch (self.src[self.start]) {
            'a' => return self.checkKeyword(1, "nd", .AND),
            'c' => return self.checkKeyword(1, "lass", .CLASS),
            'e' => return self.checkKeyword(1, "lse", .ELSE),
            'f' => {
                if (self.current - self.start > 1) {
                    switch (self.src[self.start + 1]) {
                        'a' => return self.checkKeyword(2, "lse", .FALSE),
                        'o' => return self.checkKeyword(2, "r", .FOR),
                        'u' => return self.checkKeyword(2, "n", .FUN),
                        else => {},
                    }
                }
            },
            'i' => return self.checkKeyword(1, "f", .IF),
            'n' => return self.checkKeyword(1, "il", .NIL),
            'o' => return self.checkKeyword(1, "r", .OR),
            'p' => return self.checkKeyword(1, "rint", .PRINT),
            'r' => return self.checkKeyword(1, "eturn", .RETURN),
            's' => return self.checkKeyword(1, "uper", .SUPER),
            't' => {
                if (self.current - self.start > 1) {
                    switch (self.src[self.start + 1]) {
                        'h' => return self.checkKeyword(2, "is", .THIS),
                        'r' => return self.checkKeyword(2, "ue", .TRUE),
                        else => {},
                    }
                }
            },
            'v' => return self.checkKeyword(1, "ar", .VAR),
            'w' => return self.checkKeyword(1, "hile", .WHILE),

            else => {},
        }
        return .IDENTIFIER;
    }

    fn checkKeyword(self: *Scanner, offset: usize, rest: []const u8, toktype: TokenType) TokenType {
        if (self.current - self.start != offset + rest.len) {
            return .IDENTIFIER;
        }
        const sub = self.src.ptr[self.start + offset .. self.current];
        if (std.mem.eql(u8, sub, rest)) {
            return toktype;
        }
        return .IDENTIFIER;
    }

    fn number(self: *Scanner) Token {
        while (std.ascii.isDigit(self.peek())) {
            _ = self.advance();
        }
        if (self.peek() == '.' and std.ascii.isDigit(self.peekNext())) {
            _ = self.advance();
            while (std.ascii.isDigit(self.peek())) {
                _ = self.advance();
            }
        }
        return self.makeToken(TokenType.NUMBER);
    }

    fn string(self: *Scanner) Token {
        while (self.peek() != '"' and !self.isAtEnd()) {
            if (self.peek() == '\n') self.line += 1;
            _ = self.advance();
        }
        if (self.isAtEnd()) {
            return self.errorToken("Unterminated string.");
        }

        // closing quote
        _ = self.advance();
        return self.makeToken(TokenType.STRING);
    }

    fn peek(self: *Scanner) u8 {
        if (self.isAtEnd()) return 0;
        return self.src[self.current];
    }

    fn peekNext(self: *Scanner) u8 {
        if (self.isAtEnd()) return 0;
        return self.src[self.current + 1];
    }

    fn advance(self: *Scanner) u8 {
        self.current += 1;
        return self.src[self.current - 1];
    }

    fn match(self: *Scanner, expected: u8) bool {
        if (self.isAtEnd()) {
            return false;
        }
        if (self.src[self.current] != expected) {
            return false;
        }
        self.current += 1;
        return true;
    }

    fn makeToken(self: *Scanner, toktype: TokenType) Token {
        return Token{
            .toktype = toktype,
            .lexeme = if (toktype == .EOF) "\\0" else self.src[self.start..self.current],
            .line = self.line,
        };
    }

    fn errorToken(self: *Scanner, msg: []const u8) Token {
        return Token{ .toktype = TokenType.ERROR, .lexeme = msg, .line = self.line };
    }

    fn isAtEnd(self: *Scanner) bool {
        const res = self.current >= self.src.len;
        return res;
    }
};
