module compiler;

import std.stdio;
import std.conv;

import chunk : Chunk, OpCode;
import scanner : Scanner, Token, TokenType;
import value : Value;
import lox_debug;

struct Parser {
    Token current;
    Token previous;
    bool hadError;
    bool panicMode;
}

enum Precedence {
    None,
    Assignment,
    Or,
    And,
    Equality,
    Comparison,
    Term,
    Factor,
    Unary,
    Call,
    Primary,
}

alias ParseFunction = void function(Compiler*);

struct ParseRule {
    ParseFunction prefix;
    ParseFunction infix;
    Precedence precedence;
}

ParseRule[] rules = [
    /* LeftParen    */ ParseRule(&Compiler.grouping, null,             Precedence.None  ),
    /* RightParen   */ ParseRule(null,               null,             Precedence.None  ),
    /* LeftBrace    */ ParseRule(null,               null,             Precedence.None  ),
    /* RightBrace   */ ParseRule(null,               null,             Precedence.None  ),
    /* Comma        */ ParseRule(null,               null,             Precedence.None  ),
    /* Dot          */ ParseRule(null,               null,             Precedence.None  ),
    /* Minus        */ ParseRule(&Compiler.unary,    &Compiler.binary, Precedence.Term  ),
    /* Plus         */ ParseRule(null,               &Compiler.binary, Precedence.Term  ),
    /* Semicolon    */ ParseRule(null,               null,             Precedence.None  ),
    /* Slash        */ ParseRule(null,               &Compiler.binary, Precedence.Factor),
    /* Star         */ ParseRule(null,               &Compiler.binary, Precedence.Factor),
    /* Bang         */ ParseRule(null,               null,             Precedence.None  ),
    /* BangEqual    */ ParseRule(null,               null,             Precedence.None  ),
    /* Equal        */ ParseRule(null,               null,             Precedence.None  ),
    /* EqualEqual   */ ParseRule(null,               null,             Precedence.None  ),
    /* Greater      */ ParseRule(null,               null,             Precedence.None  ),
    /* GreaterEqual */ ParseRule(null,               null,             Precedence.None  ),
    /* Less         */ ParseRule(null,               null,             Precedence.None  ),
    /* LessEqual    */ ParseRule(null,               null,             Precedence.None  ),
    /* Identifier   */ ParseRule(null,               null,             Precedence.None  ),
    /* String       */ ParseRule(null,               null,             Precedence.None  ),
    /* Number       */ ParseRule(&Compiler.number,   null,             Precedence.None  ),
    /* And          */ ParseRule(null,               null,             Precedence.None  ),
    /* Class        */ ParseRule(null,               null,             Precedence.None  ),
    /* Else         */ ParseRule(null,               null,             Precedence.None  ),
    /* False        */ ParseRule(null,               null,             Precedence.None  ),
    /* For          */ ParseRule(null,               null,             Precedence.None  ),
    /* Fun          */ ParseRule(null,               null,             Precedence.None  ),
    /* If           */ ParseRule(null,               null,             Precedence.None  ),
    /* Nil          */ ParseRule(null,               null,             Precedence.None  ),
    /* Or           */ ParseRule(null,               null,             Precedence.None  ),
    /* Print        */ ParseRule(null,               null,             Precedence.None  ),
    /* Return       */ ParseRule(null,               null,             Precedence.None  ),
    /* Super        */ ParseRule(null,               null,             Precedence.None  ),
    /* This         */ ParseRule(null,               null,             Precedence.None  ),
    /* True         */ ParseRule(null,               null,             Precedence.None  ),
    /* Var          */ ParseRule(null,               null,             Precedence.None  ),
    /* While        */ ParseRule(null,               null,             Precedence.None  ),
    /* Error        */ ParseRule(null,               null,             Precedence.None  ),
    /* EndOfFile    */ ParseRule(null,               null,             Precedence.None  ),
];

struct Compiler{
    Scanner scanner;
    Parser parser;
    Chunk* compilingChunk = null;

    bool compile(string source, Chunk* c) {
        scanner.setup(source);
        this.compilingChunk = c;

        this.advance();
        expression(&this);
        this.consume(TokenType.EndOfFile, "Expect end of expression.");
        this.end();
        return !this.parser.hadError;
    }

    private Chunk* currentChunk() {
        return compilingChunk;
    }

    private void advance() {
        this.parser.previous = this.parser.current;

        while (true) {
            this.parser.current = this.scanner.scanToken();
            if (parser.current.tok_type != TokenType.Error) {
                break;
            }

            this.errorAtCurrent(this.parser.current.lexeme);
        }
    }

    private void consume(TokenType tok_type, const string message) {
        if (this.parser.current.tok_type == tok_type) {
            this.advance();
            return;
        }

        this.errorAtCurrent(message);
    }

    private void emitByte(ubyte data) {
        this.currentChunk().write(data, this.parser.previous.line);
    }

    private void emitBytes(ubyte data1, ubyte data2) {
        this.emitByte(data1);
        this.emitByte(data2);
    }

    private void emitReturn() {
        this.emitByte(OpCode.Return);
    }

    private void emitConstant(Value val) {
        this.emitBytes(OpCode.Constant, this.makeConstant(val));
    }

    private void end() {
        this.emitReturn();
        version(DebugPrintCode) {
            if (!this.parser.hadError) {
                lox_debug.disassembleChunk(this.currentChunk(), "code");
            }
        }
    }

    private ubyte makeConstant(Value val) {
        size_t constIdx = this.currentChunk().addConstant(val);
        if (constIdx > ubyte.max)  {
            this.error("Too many constants in one chunk.");
            return 0;
        }
        return to!ubyte(constIdx);
    }

    private void parsePrecedence(Precedence precedence) {
        this.advance();
        ParseFunction prefixRule = Compiler.getRule(this.parser.previous.tok_type).prefix;
        if (prefixRule == null) {
            this.error("Expect expression.");
            return;
        }

        prefixRule(&this);

        while (precedence <= Compiler.getRule(this.parser.current.tok_type).precedence) {
            this.advance();
            ParseFunction infixRule = Compiler.getRule(this.parser.previous.tok_type).infix;
            infixRule(&this);
        }
    }

    static ParseRule* getRule(TokenType tok_type) {
        return &rules[tok_type];
    }

    static void grouping(Compiler* self) {
        Compiler.expression(self);
        self.consume(TokenType.RightParen, "Expect ')' after expression.");
    }

    static void expression(Compiler* self) {
        self.parsePrecedence(Precedence.Assignment);
    }

    static void binary(Compiler* self) {
        TokenType op = self.parser.previous.tok_type;
        ParseRule* rule = Compiler.getRule(op);
        self.parsePrecedence(to!Precedence(rule.precedence + 1));

        switch (op) {
            case TokenType.Plus: self.emitByte(OpCode.Add); break;
            case TokenType.Minus: self.emitByte(OpCode.Subtract); break;
            case TokenType.Star: self.emitByte(OpCode.Multiply); break;
            case TokenType.Slash: self.emitByte(OpCode.Divide); break;
            default: return; // should be unreachable
        }
    }

    static void unary(Compiler* self) {
        TokenType op = self.parser.previous.tok_type;

        self.parsePrecedence(Precedence.Unary);

        switch (op) {
            case TokenType.Minus: self.emitByte(OpCode.Negate); break;
            default: return; // should be unreachable
        }
    }

    static void number(Compiler* self) {
        double value = parse!double(self.parser.previous.lexeme);
        self.emitConstant(value);
    }

    private void errorAtCurrent(const string message) {
        this.errorAt(&this.parser.current, message);
    }

    private void error(const string message) {
        this.errorAt(&this.parser.previous, message);
    }

    private void errorAt(Token* tok, const string message) {
        if (this.parser.panicMode) {
            return;
        }
        this.parser.panicMode = true;

        stderr.writef("[line %d] Error", tok.line);

        if (tok.tok_type == TokenType.EndOfFile)  {
            stderr.write(" at end");
        }
        else if (tok.tok_type == TokenType.Error) {
            // no-op
        }
        else {
            stderr.writef(" at '%s'", tok.lexeme);
        }

        stderr.writefln(": %s", message);
        this.parser.hadError = true;
    }
}

