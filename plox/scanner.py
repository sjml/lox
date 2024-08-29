from .lox import Lox
from .token import Token, TokenType

class Scanner:
    _keywords: dict[str, TokenType] = {
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
        self._src = src
        self._tokens: list[Token] = []
        self._start: int = 0
        self._current: int = 0
        self._line: int = 1

    def _scan_tokens(self) -> list[Token]:
        while not self._is_at_end():
            self._start = self._current
            self._scan_token()

        self._tokens.append(Token(TokenType.EOF, "", None, self._line))
        return self._tokens

    def _scan_token(self):
        c = self._advance()
        match c:
            case "(":
                self._add_token(TokenType.LEFT_PAREN)
            case ")":
                self._add_token(TokenType.RIGHT_PAREN)
            case "{":
                self._add_token(TokenType.LEFT_BRACE)
            case "}":
                self._add_token(TokenType.RIGHT_BRACE)
            case ",":
                self._add_token(TokenType.COMMA)
            case ".":
                self._add_token(TokenType.DOT)
            case "-":
                self._add_token(TokenType.MINUS)
            case "+":
                self._add_token(TokenType.PLUS)
            case ";":
                self._add_token(TokenType.SEMICOLON)
            case "*":
                self._add_token(TokenType.STAR)
            case "!":
                self._add_token(TokenType.BANG_EQUAL if self._check_next("=") else TokenType.BANG)
            case "=":
                self._add_token(TokenType.EQUAL_EQUAL if self._check_next("=") else TokenType.EQUAL)
            case "<":
                self._add_token(TokenType.LESS_EQUAL if self._check_next("=") else TokenType.LESS)
            case ">":
                self._add_token(TokenType.GREATER_EQUAL if self._check_next("=") else TokenType.GREATER)
            case "/":
                if self._check_next("/"):
                    while self._peek() != "\n" and not self._is_at_end():
                        self._advance()
                else:
                    self._add_token(TokenType.SLASH)
            case " " | "\r" | "\t":
                pass # ignore non-newline whitespace
            case "\n":
                self._line += 1
            case "\"":
                self._string()
            case _:
                if c.isalpha():
                    self._identifier()
                elif c.isnumeric():
                    self._number()
                else:
                    Lox.error(self._line, "Unexpected character.")


    def _advance(self) -> str:
        c = self._src[self._current]
        self._current += 1
        return c

    def _add_token(self, tok_type: TokenType, literal=None):
        text = self._src[self._start:self._current]
        self._tokens.append(Token(tok_type, text, literal, self._line))

    def _is_at_end(self) -> bool:
        return self._current >= len(self._src)

    def _string(self):
        while self._peek() != "\"" and not self._is_at_end():
            if self._peek() == "\n":
                self._line += 1
            self._advance()
        if self._is_at_end():
            Lox.error(self._line, "Unterminated string.")
            return
        self._advance() # the closing "
        value = self._src[self._start+1:self._current-1]
        self._add_token(TokenType.STRING, value)

    def _number(self):
        while self._peek()[0].isnumeric():
            self._advance()
        if self._peek() == "." and self._peek_next()[0].isnumeric():
            # consume the decimal point
            self._advance()
            while self._peek()[0].isnumeric():
                self._advance()
        self._add_token(TokenType.NUMBER, float(self._src[self._start:self._current]))

    def _identifier(self):
        while self._peek()[0].isalnum() or self._peek()[0] == "_":
            self._advance()

        text = self._src[self._start:self._current]
        tok_type = Scanner._keywords.get(text)
        if not tok_type:
            tok_type = TokenType.IDENTIFIER

        self._add_token(tok_type)

    def _peek(self) -> str:
        if self._is_at_end():
            return "\0"
        return self._src[self._current]

    def _peek_next(self) -> str:
        if self._current + 1 >= len(self._src):
            return "\0"
        return self._src[self._current + 1]

    def _check_next(self, expected: str) -> bool:
        if self._is_at_end():
            return False
        if self._src[self._current] != expected:
            return False
        self._current += 1
        return True
