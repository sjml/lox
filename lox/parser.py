from __future__ import annotations

from . import ast
from .lox import Lox
from .token import Token, TokenType

class Parser:
    class ParseError(Exception):
        def __init__(self, message: str) -> None:
            super().__init__(message)

    def __init__(self, tokens: list[Token]) -> None:
        self.tokens = tokens
        self.current: int = 0

    def _expression(self) -> ast.Expr:
        return self._equality()

    def _equality(self) -> ast.Expr:
        expr = self._comparison()

        while self._match(TokenType.BANG_EQUAL, TokenType.EQUAL_EQUAL):
            operator = self._previous()
            right = self._comparison()
            expr = ast.Binary(expr, operator, right)

        return expr

    def parse(self) -> ast.Expr:
        try:
            return self._expression()
        except Parser.ParseError:
            return None

    def _comparison(self) -> ast.Expr:
        expr = self._term()

        while self._match(TokenType.GREATER, TokenType.GREATER_EQUAL, TokenType.LESS, TokenType.LESS_EQUAL):
            operator = self._previous()
            right = self._term()
            expr = ast.Binary(expr, operator, right)

        return expr

    def _term(self) -> ast.Expr:
        expr = self._factor()

        while self._match(TokenType.MINUS, TokenType.PLUS):
            operator = self._previous()
            right = self._factor()
            expr = ast.Binary(expr, operator, right)

        return expr

    def _factor(self) -> ast.Expr:
        expr = self._unary()

        while self._match(TokenType.SLASH, TokenType.STAR):
            operator = self._previous()
            right = self._unary()
            expr = ast.Binary(expr, operator, right)

        return expr

    def _unary(self) -> ast.Expr:
        if self._match(TokenType.BANG, TokenType.MINUS):
            operator = self._previous()
            right = self._unary()
            return ast.Unary(operator, right)

        return self._primary()

    def _primary(self) -> ast.Expr:
        if self._match(TokenType.FALSE):
            return ast.Literal(False)
        if self._match(TokenType.TRUE):
            return ast.Literal(True)
        if self._match(TokenType.NIL):
            return ast.Literal(None)

        if self._match(TokenType.NUMBER, TokenType.STRING):
            return ast.Literal(self._previous().literal)

        if self._match(TokenType.LEFT_PAREN):
            expr = self._expression()
            self._consume(TokenType.RIGHT_PAREN, "Expect ')' after expression.")
            return ast.Grouping(expr)

        raise self._error(self._peek(), "Expect expression.")


    def _match(self, *types: TokenType) -> bool:
        for t in types:
            if self._check(t):
                self._advance()
                return True

        return False

    def _consume(self, t: TokenType, message: str) -> Token:
        if self._check(t):
            return self._advance()
        raise Parser.ParseError(self._peek(), message)

    def _check(self, t: TokenType) -> bool:
        if self._is_at_end():
            return False
        return self._peek().type == t

    def _advance(self):
        if not self._is_at_end():
            self.current += 1
        return self._previous()

    def _is_at_end(self) -> bool:
        return self._peek().type == TokenType.EOF

    def _peek(self) -> Token:
        return self.tokens[self.current]

    def _previous(self) -> Token:
        return self.tokens[self.current - 1]

    def _error(self, token: Token, message: str) -> Parser.ParseError:
        Lox.error(token, message)
        return Parser.ParseError(message)

    def _synchronize(self):
        self._advance()

        while not self._is_at_end():
            if self._previous().type == TokenType.SEMICOLON:
                return

            if self._peek().type in [
                TokenType.CLASS,
                TokenType.FUN,
                TokenType.VAR,
                TokenType.FOR,
                TokenType.IF,
                TokenType.WHILE,
                TokenType.PRINT,
                TokenType.RETURN,
            ]:
                return

            self._advance()
