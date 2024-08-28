from enum import Enum

from . import Lox

TokenType = Enum("TokenType", [
    # single-character tokens
    "LEFT_PAREN", "RIGHT_PAREN",
    "LEFT_BRACE", "RIGHT_BRACE",
    "COMMA", "DOT",
    "MINUS", "PLUS",
    "STAR", "SLASH",
    "SEMICOLON",

    # one- or two-character tokens
    "BANG", "BANG_EQUAL",
    "EQUAL", "EQUAL_EQUAL",
    "GREATER", "GREATER_EQUAL",
    "LESS", "LESS_EQUAL",

    # literals
    "INDENTIFIER", "STRING", "NUMBER",

    # keywords
    "TRUE", "FALSE",
    "AND", "OR",
    "IF", "ELSE",
    "FOR", "WHILE",
    "RETURN",
    "CLASS", "FUN", "VAR",
    "THIS",
    "SUPER",
    "NIL",
    "PRINT",

    "EOF",
])

class Token:
    def __init__(self, tok_type: TokenType, lexeme: str, literal, line: int) -> None:
        self.type = tok_type
        self.lexeme = lexeme
        self.literal = literal
        self.line = line

    def __str__(self) -> str:
        return f"{self.type} {self.lexeme} {self.literal}"


class Scanner:
    keywords: dict[str, TokenType] = {
        "true": TokenType.TRUE,
        "false": TokenType.FALSE,
        "and": TokenType.AND,
        "or": TokenType.OR,
        "if": TokenType.IF,
        "else": TokenType.ELSE,
        "for": TokenType.FOR,
        "while": TokenType.WHILE,
        "return": TokenType.RETURN,
        "class": TokenType.CLASS,
        "fun": TokenType.FUN,
        "var": TokenType.VAR,
        "this": TokenType.THIS,
        "super": TokenType.SUPER,
        "nil": TokenType.NIL,
        "print": TokenType.PRINT,
    }

    def __init__(self, src: str) -> None:
        self.src = src
        self.tokens: list[Token] = []
        self.start = 0
        self.current = 0
        self.line = 1

    def scan_tokens(self) -> list[Token]:
        while not self.is_at_end():
            self.start = self.current
            self.scan_token()

        self.tokens.append(Token(TokenType.EOF, "", None, self.line))
        return self.tokens

    def scan_token(self):
        c = self.advance()
        match c:
            case "(":
                self.add_token(TokenType.LEFT_PAREN)
            case ")":
                self.add_token(TokenType.RIGHT_PAREN)
            case "{":
                self.add_token(TokenType.LEFT_BRACE)
            case "}":
                self.add_token(TokenType.RIGHT_BRACE)
            case ",":
                self.add_token(TokenType.COMMA)
            case ".":
                self.add_token(TokenType.DOT)
            case "-":
                self.add_token(TokenType.MINUS)
            case "+":
                self.add_token(TokenType.PLUS)
            case ";":
                self.add_token(TokenType.SEMICOLON)
            case "*":
                self.add_token(TokenType.STAR)
            case "!":
                self.add_token(TokenType.BANG_EQUAL if self.check_next("=") else TokenType.BANG)
            case "=":
                self.add_token(TokenType.EQUAL_EQUAL if self.check_next("=") else TokenType.EQUAL)
            case "<":
                self.add_token(TokenType.LESS_EQUAL if self.check_next("=") else TokenType.LESS)
            case ">":
                self.add_token(TokenType.GREATER_EQUAL if self.check_next("=") else TokenType.GREATER)
            case "/":
                if self.check_next("/"):
                    while self.peek() != "\n" and not self.is_at_end():
                        self.advance()
                else:
                    self.add_token(TokenType.SLASH)
            case " " | "\r" | "\t":
                pass # ignore non-newline whitespace
            case "\n":
                self.line += 1
            case "\"":
                self.string()
            case _:
                if c.isalpha():
                    self.identifier()
                elif c.isnumeric():
                    self.number()
                else:
                    Lox.error(self.line, "Unexpected character.")


    def advance(self) -> str:
        c = self.src[self.current]
        self.current += 1
        return c

    def add_token(self, tok_type: TokenType, literal=None):
        text = self.src[self.start:self.current]
        self.tokens.append(Token(tok_type, text, literal, self.line))

    def is_at_end(self) -> bool:
        return self.current >= len(self.src)

    def string(self):
        while self.peek() != "\"" and not self.is_at_end():
            if self.peek() == "\n":
                line += 1
            self.advance()
        if self.is_at_end():
            Lox.error(line, "Unterminated string.")
            return
        self.advance() # the closing "
        value = self.src[self.start+1:self.current-1]
        self.add_token(TokenType.STRING, value)

    def number(self):
        while self.peek()[0].isnumeric():
            self.advance()
        if self.peek() == "." and self.peek_next()[0].isnumeric():
            # consume the decimal point
            self.advance()
            while self.peek()[0].isnumeric():
                self.advance()
        self.add_token(TokenType.NUMBER, float(self.src[self.start:self.current]))

    def identifier(self):
        while self.peek()[0].isalnum() or self.peek()[0] == "_":
            self.advance()

        text = self.src[self.start:self.current]
        tok_type = Scanner.keywords.get(text)
        if not tok_type:
            tok_type = TokenType.INDENTIFIER

        self.add_token(tok_type)

    def peek(self) -> str:
        if self.is_at_end():
            return "\0"
        return self.src[self.current]

    def peek_next(self) -> str:
        if self.current + 1 >= len(self.src):
            return "\0"
        return self.src[self.current + 1]

    def check_next(self, expected: str) -> bool:
        if self.is_at_end():
            return False
        if self.src[self.current] != expected:
            return False
        self.current += 1
        return True
