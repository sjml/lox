module compiler;

import std.stdio;
import std.conv;

import chunk : Chunk, OpCode;
import scanner : Scanner, Token, TokenType;
import value : Value;
import lobj : Obj, ObjString;
import lox_debug;

struct Parser
{
    Token current;
    Token previous;
    bool hadError;
    bool panicMode;
}

enum Precedence
{
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

alias ParseFunction = void function(Compiler*, bool canAssign);

struct ParseRule
{
    ParseFunction prefix;
    ParseFunction infix;
    Precedence precedence;
}

// dfmt off
ParseRule[] rules = [
    /* LeftParen    */ ParseRule(&Compiler.grouping, null,             Precedence.None        ),
    /* RightParen   */ ParseRule(null,               null,             Precedence.None        ),
    /* LeftBrace    */ ParseRule(null,               null,             Precedence.None        ),
    /* RightBrace   */ ParseRule(null,               null,             Precedence.None        ),
    /* Comma        */ ParseRule(null,               null,             Precedence.None        ),
    /* Dot          */ ParseRule(null,               null,             Precedence.None        ),
    /* Minus        */ ParseRule(&Compiler.unary,    &Compiler.binary, Precedence.Term        ),
    /* Plus         */ ParseRule(null,               &Compiler.binary, Precedence.Term        ),
    /* Semicolon    */ ParseRule(null,               null,             Precedence.None        ),
    /* Slash        */ ParseRule(null,               &Compiler.binary, Precedence.Factor      ),
    /* Star         */ ParseRule(null,               &Compiler.binary, Precedence.Factor      ),
    /* Bang         */ ParseRule(&Compiler.unary,    null,             Precedence.None        ),
    /* BangEqual    */ ParseRule(null,               &Compiler.binary, Precedence.Equality    ),
    /* Equal        */ ParseRule(null,               null,             Precedence.None        ),
    /* EqualEqual   */ ParseRule(null,               &Compiler.binary, Precedence.Equality    ),
    /* Greater      */ ParseRule(null,               &Compiler.binary, Precedence.Comparison  ),
    /* GreaterEqual */ ParseRule(null,               &Compiler.binary, Precedence.Comparison  ),
    /* Less         */ ParseRule(null,               &Compiler.binary, Precedence.Comparison  ),
    /* LessEqual    */ ParseRule(null,               &Compiler.binary, Precedence.Comparison  ),
    /* Identifier   */ ParseRule(&Compiler.variable, null,             Precedence.None        ),
    /* String       */ ParseRule(&Compiler.sstring,  null,             Precedence.None        ),
    /* Number       */ ParseRule(&Compiler.number,   null,             Precedence.None        ),
    /* And          */ ParseRule(null,               &Compiler.and,    Precedence.And         ),
    /* Class        */ ParseRule(null,               null,             Precedence.None        ),
    /* Else         */ ParseRule(null,               null,             Precedence.None        ),
    /* False        */ ParseRule(&Compiler.literal,  null,             Precedence.None        ),
    /* For          */ ParseRule(null,               null,             Precedence.None        ),
    /* Fun          */ ParseRule(null,               null,             Precedence.None        ),
    /* If           */ ParseRule(null,               null,             Precedence.None        ),
    /* Nil          */ ParseRule(&Compiler.literal,  null,             Precedence.None        ),
    /* Or           */ ParseRule(null,               &Compiler.or,     Precedence.Or          ),
    /* Print        */ ParseRule(null,               null,             Precedence.None        ),
    /* Return       */ ParseRule(null,               null,             Precedence.None        ),
    /* Super        */ ParseRule(null,               null,             Precedence.None        ),
    /* This         */ ParseRule(null,               null,             Precedence.None        ),
    /* True         */ ParseRule(&Compiler.literal,  null,             Precedence.None        ),
    /* Var          */ ParseRule(null,               null,             Precedence.None        ),
    /* While        */ ParseRule(null,               null,             Precedence.None        ),
    /* Error        */ ParseRule(null,               null,             Precedence.None        ),
    /* EndOfFile    */ ParseRule(null,               null,             Precedence.None        ),
];
// dfmt on

struct Local {
    Token name;
    int depth;
}

struct Compiler
{
    Scanner scanner;
    Parser parser;
    Chunk* compilingChunk = null;

    Local[ubyte.max + 1] locals;
    size_t localCount = 0;
    int scopeDepth = 0;

    bool compile(string source, Chunk* c)
    {
        scanner.setup(source);
        this.compilingChunk = c;

        this.advance();
        while (!this.match(TokenType.EndOfFile)) {
            Compiler.declaration(&this);
        }
        this.end();
        return !this.parser.hadError;
    }

    private Chunk* currentChunk()
    {
        return compilingChunk;
    }

    private void advance()
    {
        this.parser.previous = this.parser.current;

        while (true)
        {
            this.parser.current = this.scanner.scanToken();
            if (parser.current.tokType != TokenType.Error)
            {
                break;
            }

            this.errorAtCurrent(this.parser.current.lexeme);
        }
    }

    private void consume(TokenType tokType, const string message)
    {
        if (this.parser.current.tokType == tokType)
        {
            this.advance();
            return;
        }

        this.errorAtCurrent(message);
    }

    private bool match(TokenType tokType) {
        if (!this.check(tokType)) {
            return false;
        }
        this.advance();
        return true;
    }

    private bool check(TokenType tokType) {
        return this.parser.current.tokType == tokType;
    }

    private void emitByte(ubyte data)
    {
        this.currentChunk().write(data, this.parser.previous.line);
    }

    private void emitBytes(ubyte data1, ubyte data2)
    {
        this.emitByte(data1);
        this.emitByte(data2);
    }

    private size_t emitJump(ubyte instruction) {
        this.emitByte(instruction);
        this.emitByte(0xff);
        this.emitByte(0xff);
        return this.currentChunk().count - 2;
    }

    private void patchJump(size_t offset) {
        size_t jump = this.currentChunk().count - offset - 2;
        if (jump > ushort.max) {
            this.error("Too much code to jump over.");
        }
        this.currentChunk().code[offset] = (jump >> 8) & 0xff;
        this.currentChunk().code[offset+1] = jump & 0xff;
    }

    private void emitLoop(size_t loopStart) {
        this.emitByte(OpCode.Loop);
        size_t offset = this.currentChunk().count - loopStart + 2;
        if (offset > ushort.max) {
            this.error("Loop body too large.");
        }
        this.emitByte((offset >> 8) & 0xff);
        this.emitByte(offset & 0xff);
    }

    private void emitReturn()
    {
        this.emitByte(OpCode.Return);
    }

    private void emitConstant(Value val)
    {
        this.emitBytes(OpCode.Constant, this.makeConstant(val));
    }

    private void end()
    {
        this.emitReturn();
        version (DebugPrintCode)
        {
            if (!this.parser.hadError)
            {
                lox_debug.disassembleChunk(this.currentChunk(), "code");
            }
        }
    }

    private void beginScope() {
        this.scopeDepth += 1;
    }

    private void endScope() {
        this.scopeDepth -= 1;

        while (
            (this.localCount > 0)
            && (this.locals[this.localCount-1].depth > this.scopeDepth)
        ) {
            this.emitByte(OpCode.Pop);
            this.localCount -= 1;
        }
    }

    private ubyte makeConstant(Value val)
    {
        size_t constIdx = this.currentChunk().addConstant(val);
        if (constIdx > ubyte.max)
        {
            this.error("Too many constants in one chunk.");
            return 0;
        }
        return to!ubyte(constIdx);
    }

    private void parsePrecedence(Precedence precedence)
    {
        this.advance();
        ParseFunction prefixRule = Compiler.getRule(this.parser.previous.tokType).prefix;
        if (prefixRule == null)
        {
            this.error("Expect expression.");
            return;
        }

        bool canAssign = precedence <= Precedence.Assignment;
        prefixRule(&this, canAssign);

        while (precedence <= Compiler.getRule(this.parser.current.tokType).precedence)
        {
            this.advance();
            ParseFunction infixRule = Compiler.getRule(this.parser.previous.tokType).infix;
            infixRule(&this, canAssign);
        }

        if (canAssign && this.match(TokenType.Equal)) {
            this.error("Invalid assignment target.");
        }
    }

    private ubyte parseVariable(string errorMessage) {
        this.consume(TokenType.Identifier, errorMessage);
        this.declareVariable();
        if (this.scopeDepth > 0) {
            return 0;
        }
        return this.identifierConstant(&this.parser.previous);
    }

    private void declareVariable() {
        if (this.scopeDepth == 0) {
            return;
        }
        Token* name = &this.parser.previous;
        if (this.localCount > 0) {
            for (int idx = to!int(this.localCount - 1); idx >= 0; idx--) {
                Local* local = &this.locals[idx];
                if (local.depth != -1 && local.depth < this.scopeDepth) {
                    break;
                }
                if (this.identifiersEqual(name, &local.name)) {
                    this.error("Already a variable with this name in this scope.");
                }
            }
        }
        this.addLocal(*name);
    }

    private void defineVariable(ubyte global) {
        if (this.scopeDepth > 0) {
            this.markInitialized();
            return;
        }
        this.emitBytes(OpCode.DefineGlobal, global);
    }

    static void and(Compiler* self, bool canAssign) {
        size_t endJump = self.emitJump(OpCode.JumpIfFalse);
        self.emitByte(OpCode.Pop);
        self.parsePrecedence(Precedence.And);
        self.patchJump(endJump);
    }

    static void or(Compiler* self, bool canAssign) {
        size_t elseJump = self.emitJump(OpCode.JumpIfFalse);
        size_t endJump = self.emitJump(OpCode.Jump);

        self.patchJump(elseJump);
        self.emitByte(OpCode.Pop);

        self.parsePrecedence(Precedence.Or);
        self.patchJump(endJump);
    }

    private void markInitialized() {
        this.locals[this.localCount - 1].depth = this.scopeDepth;
    }

    private void addLocal(Token name) {
        if (this.localCount == ubyte.max+1) {
            this.error("Too many local variables in function.");
            return;
        }
        Local* local = &this.locals[this.localCount++];
        local.name = name;
        local.depth = -1;
    }

    private int resolveLocal(Token* name) {
        if (this.localCount > 0) {
            for (int idx = to!int(this.localCount - 1); idx >= 0; idx--) {
                Local* local = &this.locals[idx];
                if (this.identifiersEqual(name, &local.name)) {
                    if (local.depth == -1) {
                        this.error("Can't read local variable in its own initializer.");
                    }
                    return idx;
                }
            }
        }
        return -1;
    }

    private ubyte identifierConstant(Token* name) {
        return this.makeConstant(Value(cast(Obj*) ObjString.fromCopyOf(name.lexeme)));
    }

    private bool identifiersEqual(Token* a, Token* b) {
        return a.lexeme == b.lexeme;
    }

    static ParseRule* getRule(TokenType tokType)
    {
        return &rules[tokType];
    }

    private void block() {
        while (!this.check(TokenType.RightBrace) && !this.check(TokenType.EndOfFile)) {
            Compiler.declaration(&this);
        }
        this.consume(TokenType.RightBrace, "Expect '}' after block.");
    }

    static void declaration(Compiler* self) {
        if (self.match(TokenType.Var)) {
            Compiler.varDeclaration(self);
        }
        else {
            Compiler.statement(self);
        }

        if (self.parser.panicMode) {
            self.synchronize();
        }
    }

    static void statement(Compiler* self) {
        if (self.match(TokenType.Print)) {
            self.printStatement();
        }
        else if (self.match(TokenType.If)) {
            self.ifStatement();
        }
        else if (self.match(TokenType.While)) {
            self.whileStatement();
        }
        else if (self.match(TokenType.For)) {
            self.forStatement();
        }
        else if (self.match(TokenType.LeftBrace)) {
            self.beginScope();
            self.block();
            self.endScope();
        }
        else {
            self.expressionStatement();
        }
    }

    static void grouping(Compiler* self, bool canAssign)
    {
        Compiler.expression(self);
        self.consume(TokenType.RightParen, "Expect ')' after expression.");
    }

    static void expression(Compiler* self)
    {
        self.parsePrecedence(Precedence.Assignment);
    }

    static void varDeclaration(Compiler* self) {
        ubyte global = self.parseVariable("Expect variable name.");

        if (self.match(TokenType.Equal)) {
            Compiler.expression(self);
        }
        else {
            self.emitByte(OpCode.Nil);
        }
        self.consume(TokenType.Semicolon, "Expect ';' after variable declaration.");

        self.defineVariable(global);
    }

    private void expressionStatement() {
        Compiler.expression(&this);
        this.consume(TokenType.Semicolon, "Expect ';' after expression.");
        this.emitByte(OpCode.Pop);
    }

    private void ifStatement() {
        this.consume(TokenType.LeftParen, "Expect '(' after 'if'.");
        Compiler.expression(&this);
        this.consume(TokenType.RightParen, "Expect ')' after condition.");

        size_t thenJump = this.emitJump(OpCode.JumpIfFalse);
        this.emitByte(OpCode.Pop);
        Compiler.statement(&this);
        size_t elseJump = emitJump(OpCode.Jump);
        this.patchJump(thenJump);
        this.emitByte(OpCode.Pop);

        if (this.match(TokenType.Else)) {
            Compiler.statement(&this);
        }
        this.patchJump(elseJump);
    }

    static void binary(Compiler* self, bool canAssign)
    {
        TokenType op = self.parser.previous.tokType;
        ParseRule* rule = Compiler.getRule(op);
        self.parsePrecedence(to!Precedence(rule.precedence + 1));

        switch (op)
        {
        case TokenType.BangEqual:
            self.emitBytes(OpCode.Equal, OpCode.Not);
            break;
        case TokenType.EqualEqual:
            self.emitByte(OpCode.Equal);
            break;
        case TokenType.Greater:
            self.emitByte(OpCode.Greater);
            break;
        case TokenType.GreaterEqual:
            self.emitBytes(OpCode.Less, OpCode.Not);
            break;
        case TokenType.Less:
            self.emitByte(OpCode.Less);
            break;
        case TokenType.LessEqual:
            self.emitBytes(OpCode.Greater, OpCode.Not);
            break;
        case TokenType.Plus:
            self.emitByte(OpCode.Add);
            break;
        case TokenType.Minus:
            self.emitByte(OpCode.Subtract);
            break;
        case TokenType.Star:
            self.emitByte(OpCode.Multiply);
            break;
        case TokenType.Slash:
            self.emitByte(OpCode.Divide);
            break;
        default:
            assert(false); // unreachable
        }
    }

    static void literal(Compiler* self, bool canAssign)
    {
        switch (self.parser.previous.tokType)
        {
        case TokenType.False:
            self.emitByte(OpCode.False);
            break;
        case TokenType.Nil:
            self.emitByte(OpCode.Nil);
            break;
        case TokenType.True:
            self.emitByte(OpCode.True);
            break;
        default:
            assert(false); // unreachable
        }
    }

    static void unary(Compiler* self, bool canAssign)
    {
        TokenType op = self.parser.previous.tokType;

        self.parsePrecedence(Precedence.Unary);

        switch (op)
        {
        case TokenType.Bang:
            self.emitByte(OpCode.Not);
            break;
        case TokenType.Minus:
            self.emitByte(OpCode.Negate);
            break;
        default:
            assert(false); // unreachable
        }
    }

    static void number(Compiler* self, bool canAssign)
    {
        double value = parse!double(self.parser.previous.lexeme);
        self.emitConstant(Value(value));
    }

    static void sstring(Compiler* self, bool canAssign)
    {
        size_t len = self.parser.previous.lexeme.length;
        ObjString* os = ObjString.fromCopyOf(self.parser.previous.lexeme[1 .. len - 1]);
        self.emitConstant(Value(cast(Obj*) os));
    }

    static void variable(Compiler* self, bool canAssign) {
        Compiler.namedVariable(self, self.parser.previous, canAssign);
    }

    static void namedVariable(Compiler* self, Token name, bool canAssign) {
        ubyte getOp, setOp;
        int arg = self.resolveLocal(&name);
        if (arg != -1) {
            getOp = OpCode.GetLocal;
            setOp = OpCode.SetLocal;
        }
        else {
            arg = self.identifierConstant(&name);
            getOp = OpCode.GetGlobal;
            setOp = OpCode.SetGlobal;
        }

        if (canAssign && self.match(TokenType.Equal)) {
            Compiler.expression(self);
            self.emitBytes(setOp, to!ubyte(arg));
        }
        else {
            self.emitBytes(getOp, to!ubyte(arg));
        }
    }

    private void printStatement() {
        Compiler.expression(&this);
        this.consume(TokenType.Semicolon, "Expect ';' after value.");
        this.emitByte(OpCode.Print);
    }

    private void whileStatement() {
        size_t loopStart = this.currentChunk().count;
        this.consume(TokenType.LeftParen, "Expect '(' after 'while'.");
        Compiler.expression(&this);
        this.consume(TokenType.RightParen, "Expect ')' after condition.");

        size_t exitJump = this.emitJump(OpCode.JumpIfFalse);
        this.emitByte(OpCode.Pop);
        Compiler.statement(&this);
        this.emitLoop(loopStart);

        this.patchJump(exitJump);
        this.emitByte(OpCode.Pop);
    }

    private void forStatement() {
        this.beginScope();
        this.consume(TokenType.LeftParen, "Expect '(' after 'for'.");
        if (this.match(TokenType.Semicolon)) {
            // no-op
        } else if (this.match(TokenType.Var)) {
            Compiler.varDeclaration(&this);
        }
        else {
            this.expressionStatement();
        }

        size_t loopStart = this.currentChunk().count;

        size_t exitJump = -1; // yikes, I know
        if (!this.match(TokenType.Semicolon)) {
            Compiler.expression(&this);
            this.consume(TokenType.Semicolon, "Expect ';' after loop condition.");
            exitJump = this.emitJump(OpCode.JumpIfFalse);
            this.emitByte(OpCode.Pop);
        }

        if (!this.match(TokenType.RightParen)) {
            size_t bodyJump = this.emitJump(OpCode.Jump);
            size_t incrementStart = this.currentChunk().count;
            Compiler.expression(&this);
            this.emitByte(OpCode.Pop);
            this.consume(TokenType.RightParen, "Expect ')' after for clauses.");
            this.emitLoop(loopStart);
            loopStart = incrementStart;
            this.patchJump(bodyJump);
        }

        Compiler.statement(&this);
        this.emitLoop(loopStart);

        if (exitJump != -1) {
            this.patchJump(exitJump);
            this.emitByte(OpCode.Pop);
        }

        this.endScope();
    }

    private void synchronize() {
        this.parser.panicMode = false;

        while (this.parser.current.tokType != TokenType.EndOfFile) {
            if (this.parser.previous.tokType == TokenType.Semicolon) {
                return;
            }
            switch (this.parser.current.tokType) {
                case TokenType.Class | TokenType.Fun | TokenType.Var | TokenType.For | TokenType.If
                    | TokenType.While | TokenType.Print | TokenType.Return:
                    return;
                default:
                    break; //
            }

            this.advance();
        }
    }

    private void errorAtCurrent(const string message)
    {
        this.errorAt(&this.parser.current, message);
    }

    private void error(const string message)
    {
        this.errorAt(&this.parser.previous, message);
    }

    private void errorAt(Token* tok, const string message)
    {
        if (this.parser.panicMode)
        {
            return;
        }
        this.parser.panicMode = true;

        stderr.writef("[line %d] Error", tok.line);

        if (tok.tokType == TokenType.EndOfFile)
        {
            stderr.write(" at end");
        }
        else if (tok.tokType == TokenType.Error)
        {
            // no-op
        }
        else
        {
            stderr.writef(" at '%s'", tok.lexeme);
        }

        stderr.writefln(": %s", message);
        this.parser.hadError = true;
    }
}
