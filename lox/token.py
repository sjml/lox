from enum import Enum

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
