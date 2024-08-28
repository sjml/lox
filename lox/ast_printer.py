from . import ast

class AstPrinter(ast.expr.Expr.Visitor):
    def print(self, expr: ast.expr.Expr) -> str:
        return expr.accept(self)

    def parenthesize(self, name: str, *exprs: ast.expr.Expr):
        return f"({name}{' ' if len(exprs) > 0 else ''}{' '.join([e.accept(self) for e in exprs])})"

    def visit_binary_expr(self, expr: ast.expr.Binary):
        return self.parenthesize(expr.operator.lexeme, expr.left, expr.right)

    def visit_grouping_expr(self, expr: ast.expr.Grouping):
        return self.parenthesize("group", expr.expression)

    def visit_literal_expr(self, expr: ast.expr.Literal):
        if expr.value == None:
            return "nil"
        return str(expr.value)

    def visit_unary_expr(self, expr: ast.expr.Unary):
        return self.parenthesize(expr.operator.lexeme, expr.right)

