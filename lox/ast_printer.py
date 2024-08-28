from . import ast

class AstPrinter(ast.ExprVisitor):
    def print(self, expr: ast.Expr) -> str:
        return expr.accept(self)

    def parenthesize(self, name: str, *exprs: ast.Expr):
        return f"({name}{' ' if len(exprs) > 0 else ''}{' '.join([e.accept(self) for e in exprs])})"

    def visit_binary_expr(self, expr: ast.Binary) -> str:
        return self.parenthesize(expr.operator.lexeme, expr.left, expr.right)

    def visit_grouping_expr(self, expr: ast.Grouping) -> str:
        return self.parenthesize("group", expr.expression)

    def visit_literal_expr(self, expr: ast.Literal) -> str:
        if expr.value == None:
            return "nil"
        return str(expr.value)

    def visit_unary_expr(self, expr: ast.Unary) -> str:
        return self.parenthesize(expr.operator.lexeme, expr.right)

# run with `python -m lox.ast_printer`
if __name__ == "__main__":
    from .ast import Binary, Unary, Grouping, Literal
    from .token import Token, TokenType

    expression = Binary(
        Unary(
            Token(TokenType.MINUS, "-", None, 1),
            Literal(123)
        ),
        Token(TokenType.STAR, "*", None, 1),
        Grouping(Literal(45.67))
    )

    printer = AstPrinter()
    print(printer.print(expression))
