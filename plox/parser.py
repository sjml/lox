from __future__ import annotations

from .lox import Lox
from . import ast
from .token import Token, TokenType

class Parser:
    class ParseError(Exception):
        def __init__(self, token: Token, message: str) -> None:
            super().__init__(token, message)
            self.token = token
            self.message = message

    def __init__(self, tokens: list[Token]) -> None:
        self._tokens = tokens
        self._current: int = 0


    def parse(self) -> list[ast.stmt.Stmt]:
        statements: list[ast.stmt.Stmt] = []

        while not self._is_at_end():
            statements.append(self._declaration())

        return statements

    def _expression(self) -> ast.expr.Expr:
        return self._assignment()

    def _assignment(self) -> ast.expr.Expr:
        expr = self._or()

        if self._match(TokenType.EQUAL):
            equals = self._previous()
            value = self._assignment()

            if isinstance(expr, ast.expr.Variable):
                name = expr.name
                return ast.expr.Assign(name, value)
            elif isinstance(expr, ast.expr.Get):
                return ast.expr.Set(expr.obj, expr.name, value)

            Lox.error(equals, "Invalid assignment target.")

        return expr

    def _or(self) -> ast.expr.Expr:
        expr = self._and()

        while self._match(TokenType.OR):
            operator = self._previous()
            right = self._and()
            expr = ast.expr.Logical(expr, operator, right)

        return expr

    def _and(self) -> ast.expr.Expr:
        expr = self._equality()

        while self._match(TokenType.AND):
            operator = self._previous()
            right = self._equality()
            expr = ast.expr.Logical(expr, operator, right)

        return expr

    def _declaration(self) -> ast.stmt.Stmt:
        try:
            if self._match(TokenType.CLASS):
                return self._class_declaration()
            if self._match(TokenType.FUN):
                return self._function("function")
            if self._match(TokenType.VAR):
                return self._var_declaration()
            return self._statement()
        except Parser.ParseError as pe:
            Lox.error(pe.token, pe.message)
            self._synchronize()
            return None

    def _class_declaration(self) -> ast.stmt.Stmt:
        name = self._consume(TokenType.INDENTIFIER, "Expect class name.")
        self._consume(TokenType.LEFT_BRACE, "Expect '{' before class body.")

        methods: list[ast.stmt.Function] = []
        while not self._check(TokenType.RIGHT_BRACE) and not self._is_at_end():
            methods.append(self._function("method"))

        self._consume(TokenType.RIGHT_BRACE, "Expect '}' after class body.")
        return ast.stmt.Class(name, methods)


    def _statement(self) -> ast.stmt.Stmt:
        if self._match(TokenType.FOR):
            return self._for_statement()
        if self._match(TokenType.IF):
            return self._if_statement()
        if self._match(TokenType.PRINT):
            return self._print_statement()
        if self._match(TokenType.RETURN):
            return self._return_statement()
        if self._match(TokenType.WHILE):
            return self._while_statement()
        if self._match(TokenType.LEFT_BRACE):
            return ast.stmt.Block(self._block())
        return self._expression_statement()

    def _for_statement(self) -> ast.stmt.Stmt:
        self._consume(TokenType.LEFT_PAREN, "Expect '(' after 'for'.")
        if self._match(TokenType.SEMICOLON):
            initializer = None
        elif self._match(TokenType.VAR):
            initializer = self._var_declaration()
        else:
            initializer = self._expression_statement()

        condition = None
        if not self._check(TokenType.SEMICOLON):
            condition = self._expression()
        self._consume(TokenType.SEMICOLON, "Expect ';' after loop condition.")

        increment = None
        if not self._check(TokenType.RIGHT_PAREN):
            increment = self._expression()
        self._consume(TokenType.RIGHT_PAREN, "Expect ')' after for clauses.")

        body = self._statement()

        if increment:
            body = ast.stmt.Block([
                body,
                ast.stmt.Expression(increment),
            ])

        if condition == None:
            condition = ast.expr.Literal(True)
        body = ast.stmt.While(condition, body)

        if initializer:
            body = ast.stmt.Block([
                initializer,
                body
            ])

        return body

    def _if_statement(self) -> ast.stmt.Stmt:
        self._consume(TokenType.LEFT_PAREN, "Expect '(' after 'if'.")
        condition = self._expression()
        self._consume(TokenType.RIGHT_PAREN, "Expect ')' after if condition.")

        then_branch = self._statement()
        else_branch = None
        if self._match(TokenType.ELSE):
            else_branch = self._statement()

        return ast.stmt.If(condition, then_branch, else_branch)

    def _print_statement(self) -> ast.stmt.Stmt:
        value = self._expression()
        self._consume(TokenType.SEMICOLON, "Expect ';' after value.")
        return ast.stmt.Print(value)

    def _return_statement(self) -> ast.stmt.Stmt:
        keyword = self._previous()
        value = None
        if not self._check(TokenType.SEMICOLON):
            value = self._expression()
        self._consume(TokenType.SEMICOLON, "Expect ';' after return value.")
        return ast.stmt.Return(keyword, value)

    def _var_declaration(self) -> ast.stmt.Stmt:
        name = self._consume(TokenType.INDENTIFIER, "Expect variable name.")
        initializer = None
        if self._match(TokenType.EQUAL):
            initializer = self._expression()
        self._consume(TokenType.SEMICOLON, "Expect ';' after variable declaration.")
        return ast.stmt.Var(name, initializer)

    def _while_statement(self) -> ast.stmt.Stmt:
        self._consume(TokenType.LEFT_PAREN, "Expect '(' after 'while'.")
        condition = self._expression()
        self._consume(TokenType.RIGHT_PAREN, "Expect ')' after condition.")
        body = self._statement()
        return ast.stmt.While(condition, body)

    def _expression_statement(self) -> ast.stmt.Stmt:
        expr = self._expression()
        self._consume(TokenType.SEMICOLON, "Expect ';' after expression.")
        return ast.stmt.Expression(expr)

    def _function(self, kind: str) -> ast.stmt.Function:
        name = self._consume(TokenType.INDENTIFIER, f"Expect {kind} name.")
        self._consume(TokenType.LEFT_PAREN, f"Expect '(' after {kind} name.")
        parameters: list[Token] = []
        if not self._check(TokenType.RIGHT_PAREN):
            while True:
                if len(parameters) >= 255:
                    Lox.error(self._peek(), "Can't have more than 255 parameters.")
                parameters.append(self._consume(TokenType.INDENTIFIER, "Expect parameter name."))
                if not self._match(TokenType.COMMA):
                    break
        self._consume(TokenType.RIGHT_PAREN, "Expect ')' after parameters.")

        self._consume(TokenType.LEFT_BRACE, f"Expect '{{' before {kind} body.")
        body = self._block()
        return ast.stmt.Function(name, parameters, body)

    def _block(self) -> list[ast.stmt.Stmt]:
        statements: list[ast.stmt.Stmt] = []

        while (not self._check(TokenType.RIGHT_BRACE) and not self._is_at_end()):
            statements.append(self._declaration())

        self._consume(TokenType.RIGHT_BRACE, "Expect '}' after block.")
        return statements

    def _equality(self) -> ast.expr.Expr:
        expr = self._comparison()

        while self._match(TokenType.BANG_EQUAL, TokenType.EQUAL_EQUAL):
            operator = self._previous()
            right = self._comparison()
            expr = ast.expr.Binary(expr, operator, right)

        return expr

    def _comparison(self) -> ast.expr.Expr:
        expr = self._term()

        while self._match(TokenType.GREATER, TokenType.GREATER_EQUAL, TokenType.LESS, TokenType.LESS_EQUAL):
            operator = self._previous()
            right = self._term()
            expr = ast.expr.Binary(expr, operator, right)

        return expr

    def _term(self) -> ast.expr.Expr:
        expr = self._factor()

        while self._match(TokenType.MINUS, TokenType.PLUS):
            operator = self._previous()
            right = self._factor()
            expr = ast.expr.Binary(expr, operator, right)

        return expr

    def _factor(self) -> ast.expr.Expr:
        expr = self._unary()

        while self._match(TokenType.SLASH, TokenType.STAR):
            operator = self._previous()
            right = self._unary()
            expr = ast.expr.Binary(expr, operator, right)

        return expr

    def _unary(self) -> ast.expr.Expr:
        if self._match(TokenType.BANG, TokenType.MINUS):
            operator = self._previous()
            right = self._unary()
            return ast.expr.Unary(operator, right)

        return self._call()

    def _finish_call(self, callee: ast.expr.Expr) -> ast.expr.Expr:
        arguments: list[ast.expr.Expr] = []
        if not self._check(TokenType.RIGHT_PAREN):
            while True:
                if len(arguments) >= 255:
                    Lox.error(self._peek(), "Can't have more than 255 arguments.")
                arguments.append(self._expression())
                if not self._match(TokenType.COMMA):
                    break
        paren = self._consume(TokenType.RIGHT_PAREN, "Expect ')' after arguments.")

        return ast.expr.Call(callee, paren, arguments)


    def _call(self) -> ast.expr.Expr:
        expr = self._primary()

        while True:
            if self._match(TokenType.LEFT_PAREN):
                expr = self._finish_call(expr)
            elif self._match(TokenType.DOT):
                name = self._consume(TokenType.INDENTIFIER, "Expect property name after '.'.")
                expr = ast.expr.Get(expr, name)
            else:
                break

        return expr

    def _primary(self) -> ast.expr.Expr:
        if self._match(TokenType.FALSE):
            return ast.expr.Literal(False)
        if self._match(TokenType.TRUE):
            return ast.expr.Literal(True)
        if self._match(TokenType.NIL):
            return ast.expr.Literal(None)

        if self._match(TokenType.NUMBER, TokenType.STRING):
            return ast.expr.Literal(self._previous().literal)

        if self._match(TokenType.THIS):
            return ast.expr.This(self._previous())

        if self._match(TokenType.INDENTIFIER):
            return ast.expr.Variable(self._previous())

        if self._match(TokenType.LEFT_PAREN):
            expr = self._expression()
            self._consume(TokenType.RIGHT_PAREN, "Expect ')' after expression.")
            return ast.expr.Grouping(expr)

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
            self._current += 1
        return self._previous()

    def _is_at_end(self) -> bool:
        return self._peek().type == TokenType.EOF

    def _peek(self) -> Token:
        return self._tokens[self._current]

    def _previous(self) -> Token:
        return self._tokens[self._current - 1]

    def _error(self, token: Token, message: str) -> Parser.ParseError:
        return Parser.ParseError(token, message)

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
