module scanner;

enum TokenType
{
    // single-character
    LeftParen,
    RightParen,
    LeftBrace,
    RightBrace,
    Comma,
    Dot,
    Minus,
    Plus,
    Semicolon,
    Slash,
    Star,

    // one- or two-character
    Bang,
    BangEqual,
    Equal,
    EqualEqual,
    Greater,
    GreaterEqual,
    Less,
    LessEqual,

    // literals
    Identifier,
    String,
    Number,

    // keywords
    And,
    Class,
    Else,
    False,
    For,
    Fun,
    If,
    Nil,
    Or,
    Print,
    Return,
    Super,
    This,
    True,
    Var,
    While,

    Error,
    EndOfFile,
}

struct Token
{
    TokenType tokType;
    string lexeme;
    size_t line;
}

struct Scanner
{
    string source;
    immutable(char)* start = null;
    immutable(char)* current = null;
    size_t line;

    void setup(string source)
    {
        this.source = source;
        this.start = source.ptr;
        this.current = this.start;
        this.line = 1;
    }

    Token scanToken()
    {
        if (this.isAtEnd())
        {
            return this.makeToken(TokenType.EndOfFile);
        }

        this.skipWhitespaceAndComments();
        this.start = this.current;

        if (this.isAtEnd())
        {
            return this.makeToken(TokenType.EndOfFile);
        }

        char c = this.advance();

        if (this.isDigit(c))
        {
            return this.number();
        }

        if (this.isAlpha(c))
        {
            return this.identifier();
        }

        switch (c)
        {
        case '(':
            return this.makeToken(TokenType.LeftParen);
        case ')':
            return this.makeToken(TokenType.RightParen);
        case '{':
            return this.makeToken(TokenType.LeftBrace);
        case '}':
            return this.makeToken(TokenType.RightBrace);
        case ';':
            return this.makeToken(TokenType.Semicolon);
        case ',':
            return this.makeToken(TokenType.Comma);
        case '.':
            return this.makeToken(TokenType.Dot);
        case '-':
            return this.makeToken(TokenType.Minus);
        case '+':
            return this.makeToken(TokenType.Plus);
        case '/':
            return this.makeToken(TokenType.Slash);
        case '*':
            return this.makeToken(TokenType.Star);
        case '!':
            return this.makeToken(this.match('=') ? TokenType.BangEqual : TokenType.Bang);
        case '=':
            return this.makeToken(this.match('=') ? TokenType.EqualEqual : TokenType.Equal);
        case '<':
            return this.makeToken(this.match('=') ? TokenType.LessEqual : TokenType.Less);
        case '>':
            return this.makeToken(this.match('=') ? TokenType.GreaterEqual : TokenType.Greater);
        case '"':
            return this.sstring();

        default:
            return this.errorToken("Unexpected character.");
        }
    }

    private bool isAtEnd()
    {
        return this.current - this.source.ptr >= this.source.length;
        // return *this.current == '\0';
    }

    private char advance()
    {
        this.current++;
        return this.current[-1];
    }

    private char peek()
    {
        return *this.current;
    }

    private char peekNext()
    {
        if (this.isAtEnd())
        {
            return '\0';
        }
        return this.current[1];
    }

    private bool match(char expected)
    {
        if (this.isAtEnd())
            return false;
        if (*this.current != expected)
            return false;
        this.current += 1;
        return true;
    }

    private bool isDigit(char c)
    {
        return c >= '0' && c <= '9';
    }

    private bool isAlpha(char c)
    {
        return ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_');
    }

    private TokenType checkKeyword(size_t start, string rest, TokenType tokType)
    {
        if (this.current - this.start != start + rest.length)
        {
            return TokenType.Identifier;
        }
        for (size_t i = 0; i < rest.length; i++)
        {
            if (this.start[start + i] != rest[i])
            {
                return TokenType.Identifier;
            }
        }
        return tokType;
    }

    private void skipWhitespaceAndComments()
    {
        while (true)
        {
            char c = this.peek();
            switch (c)
            {
            case ' ', '\r', '\t':
                this.advance();
                break;
            case '\n':
                this.line += 1;
                this.advance();
                break;
            case '/':
                if (this.peekNext() == '/')
                {
                    while (this.peek() != '\n' && !this.isAtEnd())
                    {
                        this.advance();
                    }
                }
                else
                {
                    return;
                }
                break;
            default:
                return;
            }
        }
    }

    private Token sstring()
    {
        while (this.peek() != '"' && !this.isAtEnd())
        {
            if (this.peek() == '\n')
            {
                this.line++;
            }
            this.advance();
        }

        if (this.isAtEnd())
        {
            return this.errorToken("Unterminated string.");
        }

        this.advance();
        return this.makeToken(TokenType.String);
    }

    private Token number()
    {
        while (this.isDigit(this.peek()))
        {
            this.advance();
        }

        if (this.peek() == '.' && this.isDigit(this.peekNext()))
        {
            this.advance();
            while (this.isDigit(this.peek()))
            {
                this.advance();
            }
        }

        return this.makeToken(TokenType.Number);
    }

    private TokenType identifierType()
    {
        switch (this.start[0])
        {
        case 'a':
            return this.checkKeyword(1, "nd", TokenType.And);
        case 'c':
            return this.checkKeyword(1, "lass", TokenType.Class);
        case 'e':
            return this.checkKeyword(1, "lse", TokenType.Else);
        case 'f':
            if (this.current - this.start > 1)
            {
                switch (this.start[1])
                {
                case 'a':
                    return this.checkKeyword(2, "lse", TokenType.False);
                case 'o':
                    return this.checkKeyword(2, "r", TokenType.For);
                case 'u':
                    return this.checkKeyword(2, "n", TokenType.Fun);
                default:
                    break;
                }
            }
            break;
        case 'i':
            return this.checkKeyword(1, "f", TokenType.If);
        case 'n':
            return this.checkKeyword(1, "il", TokenType.Nil);
        case 'o':
            return this.checkKeyword(1, "r", TokenType.Or);
        case 'p':
            return this.checkKeyword(1, "rint", TokenType.Print);
        case 'r':
            return this.checkKeyword(1, "eturn", TokenType.Return);
        case 's':
            return this.checkKeyword(1, "uper", TokenType.Super);
        case 't':
            if (this.current - this.start > 1)
            {
                switch (this.start[1])
                {
                case 'h':
                    return this.checkKeyword(2, "is", TokenType.This);
                case 'r':
                    return this.checkKeyword(2, "ue", TokenType.True);
                default:
                    break;
                }
            }
            break;
        case 'v':
            return this.checkKeyword(1, "ar", TokenType.Var);
        case 'w':
            return this.checkKeyword(1, "while", TokenType.While);
        default:
            break;
        }

        return TokenType.Identifier;
    }

    private Token identifier()
    {
        while (this.isAlpha(this.peek()) || this.isDigit(this.peek()))
        {
            this.advance();
        }
        return this.makeToken(this.identifierType());
    }

    private Token makeToken(TokenType type)
    {
        Token tok;
        tok.tokType = type;
        tok.lexeme = this.start[0 .. (this.current - this.start)];
        tok.line = this.line;
        return tok;
    }

    private Token errorToken(string message)
    {
        Token tok;
        tok.tokType = TokenType.Error;
        tok.lexeme = message;
        tok.line = this.line;
        return tok;
    }
}
