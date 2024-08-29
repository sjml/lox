from enum import Enum

from .lox import Lox
from . import ast
from .token import Token
from .interpreter import Interpreter

FunctionType = Enum("FunctionType", ["NONE", "FUNCTION", "METHOD", "INITIALIZER"])
ClassType = Enum("ClassType", ["NONE", "CLASS", "SUBCLASS"])

class Resolver(ast.expr.ExprVisitor, ast.stmt.StmtVisitor):
    def __init__(self, interpreter: Interpreter) -> None:
        self._interpreter = interpreter
        self._scopes: list[dict[str,bool]] = []
        self._current_function = FunctionType.NONE
        self._current_class = ClassType.NONE

    def resolve(self, target: list[ast.stmt.Stmt]|ast.stmt.Stmt|ast.expr.Expr):
        if type(target) == list:
            for statement in target:
                self.resolve(statement)
        elif isinstance(target, ast.stmt.Stmt):
            target.accept(self)
        elif isinstance(target, ast.expr.Expr):
            target.accept(self)

    def _resolve_function(self, function: ast.stmt.Function, ft: FunctionType):
        enclosing_function = self._current_function
        self._current_function = ft

        self._begin_scope()
        for param in function.params:
            self._declare(param)
            self._define(param)
        self.resolve(function.body)
        self._end_scope()

        self._current_function = enclosing_function

    def _begin_scope(self):
        self._scopes.append({})

    def _end_scope(self):
        self._scopes.pop()

    def _declare(self, name: Token):
        if len(self._scopes) == 0:
            return
        scope = self._scopes[-1]
        if name.lexeme in scope:
            Lox.error(name, "Already a variable with this name in this scope.")
        scope[name.lexeme] = False

    def _define(self, name: Token):
        if len(self._scopes) == 0:
            return
        self._scopes[-1][name.lexeme] = True

    def _resolve_local(self, expr: ast.expr.Expr, name: Token):
        for i in range(len(self._scopes)-1, -1, -1):
            if name.lexeme in self._scopes[i]:
                self._interpreter.resolve(expr, len(self._scopes) - 1 - i)
                return

    def visit_block_stmt(self, stmt: ast.stmt.Block):
        self._begin_scope()
        self.resolve(stmt.statements)
        self._end_scope()

    def visit_class_stmt(self, stmt: ast.stmt.Class):
        enclosing_class = self._current_class
        self._current_class = ClassType.CLASS

        self._declare(stmt.name)
        self._define(stmt.name)

        if stmt.superclass != None and stmt.name.lexeme == stmt.superclass.name.lexeme:
            Lox.error(stmt.superclass.name, "A class can't inherit from itself.")

        if stmt.superclass != None:
            self._current_class = ClassType.SUBCLASS
            self.resolve(stmt.superclass)

        if stmt.superclass != None:
            self._begin_scope()
            self._scopes[-1]["super"] = True

        self._begin_scope()
        self._scopes[-1]["this"] = True

        for method in stmt.methods:
            declaration = FunctionType.METHOD
            if method.name.lexeme == "init":
                declaration = FunctionType.INITIALIZER
            self._resolve_function(method, declaration)

        self._end_scope()

        if stmt.superclass != None:
            self._end_scope()

        self._current_class = enclosing_class

    def visit_expression_stmt(self, stmt: ast.stmt.Expression):
        self.resolve(stmt.expression)

    def visit_function_stmt(self, stmt: ast.stmt.Function):
        self._declare(stmt.name)
        self._define(stmt.name)
        self._resolve_function(stmt, FunctionType.FUNCTION)

    def visit_if_stmt(self, stmt: ast.stmt.If):
        self.resolve(stmt.condition)
        self.resolve(stmt.then_branch)
        if stmt.else_branch:
            self.resolve(stmt.else_branch)

    def visit_print_stmt(self, stmt: ast.stmt.Print):
        self.resolve(stmt.expression)

    def visit_return_stmt(self, stmt: ast.stmt.Return):
        if self._current_function == FunctionType.NONE:
            Lox.error(stmt.keyword, "Can't return from top-level code.")
        if stmt.value:
            if self._current_function == FunctionType.INITIALIZER:
                Lox.error(stmt.keyword, "Can't return a value from an initializer.")
            self.resolve(stmt.value)

    def visit_var_stmt(self, stmt: ast.stmt.Var):
        self._declare(stmt.name)
        if stmt.initializer:
            self.resolve(stmt.initializer)
        self._define(stmt.name)

    def visit_while_stmt(self, stmt: ast.stmt.While):
        self.resolve(stmt.condition)
        self.resolve(stmt.body)

    def visit_assign_expr(self, expr: ast.expr.Assign):
        self.resolve(expr.value)
        self._resolve_local(expr, expr.name)

    def visit_binary_expr(self, expr: ast.expr.Binary):
        self.resolve(expr.left)
        self.resolve(expr.right)

    def visit_call_expr(self, expr: ast.expr.Call):
        self.resolve(expr.callee)
        for argument in expr.arguments:
            self.resolve(argument)

    def visit_get_expr(self, expr: ast.expr.Get):
        self.resolve(expr.obj)

    def visit_grouping_expr(self, expr: ast.expr.Grouping):
        self.resolve(expr.expression)

    def visit_literal_expr(self, expr: ast.expr.Literal):
        pass

    def visit_logical_expr(self, expr: ast.expr.Logical):
        self.resolve(expr.left)
        self.resolve(expr.right)

    def visit_set_expr(self, expr: ast.expr.Set):
        self.resolve(expr.value)
        self.resolve(expr.obj)

    def visit_super_expr(self, expr: ast.expr.Super):
        if self._current_class == ClassType.NONE:
            Lox.error(expr.keyword, "Can't use 'super' outside of a class.")
        elif self._current_class != ClassType.SUBCLASS:
            Lox.error(expr.keyword, "Can't use 'super' in a class with no superclass.")

        self._resolve_local(expr, expr.keyword)

    def visit_this_expr(self, expr: ast.expr.This):
        if self._current_class == ClassType.NONE:
            Lox.error(expr.keyword, "Can't use 'this' outside of a class.")
            return
        self._resolve_local(expr, expr.keyword)

    def visit_unary_expr(self, expr: ast.expr.Unary):
        self.resolve(expr.right)

    def visit_variable_expr(self, expr: ast.expr.Variable):
        if len(self._scopes) != 0 and self._scopes[-1].get(expr.name.lexeme) == False:
            Lox.error(expr.name, "Can't read local variable in its own initializer.")
        self._resolve_local(expr, expr.name)


