from __future__ import annotations
from typing import assert_never
import math
import time

from .lox import LoxRuntimeError, Lox
from . import ast
from .scanner import Token, TokenType
from .environment import Environment
from .callable import Callable
from .function import Function
from .ret import LoxReturn
from .klass import LoxClass, LoxInstance

class Interpreter(ast.expr.ExprVisitor, ast.stmt.StmtVisitor):
    class ClockFunction(Callable):
        def arity(self) -> int:
            return 0

        def call(self, interpreter: Interpreter, arguments: list[object]) -> object:
            return time.time_ns() / 1000000.0

        def __str__(self):
            return "<native fn>"

    def __init__(self) -> None:
        self._globals = Environment()
        self._locals: dict[ast.expr.Expr,int] = {}
        self._environment = self._globals

        self._globals.define("clock", Interpreter.ClockFunction())

    def interpret(self, statements: list[ast.stmt.Stmt]):
        try:
            for statement in statements:
                self._execute(statement)
        except LoxRuntimeError as lre:
            Lox.runtime_error(lre)

    def _stringify(self, obj: object) -> str:
        if obj == None:
            return "nil"
        if type(obj) == float:
            if obj.is_integer():
                if obj == 0.0:
                    # special case to pass jlox test suite
                    #   (mimicking Java behavior with negative zero)
                    if math.copysign(1.0, obj) == -1.0:
                        return "-0"
                    else:
                        return "0"
                return str(int(obj))
        if type(obj) == bool:
            return str(obj).lower()
        return str(obj)

    def _execute(self, stmt: ast.stmt.Stmt):
        stmt.accept(self)

    def resolve(self, expr: ast.expr.Expr, depth: int):
        self._locals[expr] = depth

    def execute_block(self, statements: list[ast.stmt.Stmt], environment: Environment):
        previous = self._environment
        try:
            self._environment = environment
            for statement in statements:
                self._execute(statement)
        finally:
            self._environment = previous

    def visit_block_stmt(self, stmt: ast.stmt.Block):
        self.execute_block(stmt.statements, Environment(self._environment))

    def visit_class_stmt(self, stmt: ast.stmt.Class):
        self._environment.define(stmt.name.lexeme, None)
        methods: dict[str,Function] = {}
        for method in stmt.methods:
            function = Function(method, self._environment, method.name.lexeme == "init")
            methods[method.name.lexeme] = function

        klass = LoxClass(stmt.name.lexeme, methods)
        self._environment.assign(stmt.name, klass)

    def visit_literal_expr(self, expr: ast.expr.Literal):
        return expr.value

    def visit_logical_expr(self, expr: ast.expr.Logical):
        left = self._evaluate(expr.left)

        if expr.operator.type == TokenType.OR:
            if self._is_truthy(left):
                return left
        else:
            if not self._is_truthy(left):
                return left

        return self._evaluate(expr.right)

    def visit_set_expr(self, expr: ast.expr.Set) -> object:
        obj = self._evaluate(expr.obj)
        if not isinstance(obj, LoxInstance):
            raise LoxRuntimeError(expr.name, "Only instances have fields.")
        value = self._evaluate(expr.value)
        obj.set(expr.name, value)
        return value

    def visit_this_expr(self, expr: ast.expr.This) -> object:
        return self._look_up_variable(expr.keyword, expr)

    def visit_unary_expr(self, expr: ast.expr.Unary):
        right = self._evaluate(expr.right)

        match expr.operator.type:
            case TokenType.MINUS:
                self._check_number_operand(expr.operator, right)
                return -float(right)
            case TokenType.BANG:
                return not self._is_truthy(right)
            case _:
                assert_never(expr.operator.type)

    def visit_grouping_expr(self, expr: ast.expr.Grouping):
        return self._evaluate(expr.expression)

    def visit_binary_expr(self, expr: ast.expr.Binary):
        left = self._evaluate(expr.left)
        right = self._evaluate(expr.right)

        match expr.operator.type:
            case TokenType.GREATER:
                self._check_number_operands(expr.operator, left, right)
                return float(left) > float(right)
            case TokenType.GREATER_EQUAL:
                self._check_number_operands(expr.operator, left, right)
                return float(left) >= float(right)
            case TokenType.LESS:
                self._check_number_operands(expr.operator, left, right)
                return float(left) < float(right)
            case TokenType.LESS_EQUAL:
                self._check_number_operands(expr.operator, left, right)
                return float(left) <= float(right)
            case TokenType.BANG_EQUAL:
                return not self._is_equal(left, right)
            case TokenType.EQUAL_EQUAL:
                return self._is_equal(left, right)
            case TokenType.MINUS:
                self._check_number_operands(expr.operator, left, right)
                return float(left) - float(right)
            case TokenType.PLUS:
                self._check_number_or_string_operands(expr.operator, left, right)
                return (left) + (right)
            case TokenType.SLASH:
                self._check_number_operands(expr.operator, left, right)
                if right == 0.0:
                    raise LoxRuntimeError(expr.operator, "Cannot divide by zero.")
                return float(left) / float(right)
            case TokenType.STAR:
                self._check_number_operands(expr.operator, left, right)
                return float(left) * float(right)
            case _:
                assert_never(expr.operator.type)

    def visit_call_expr(self, expr: ast.stmt.Call):
        callee = self._evaluate(expr.callee)

        arguments = []
        for argument in expr.arguments:
            arguments.append(self._evaluate(argument))

        if not isinstance(callee, Callable):
            raise LoxRuntimeError(expr.paren, "Can only call functions and classes.")
        if len(arguments) != callee.arity():
            raise LoxRuntimeError(expr.paren, f"Expected {callee.arity()} arguments but got {len(arguments)}.")

        return callee.call(self, arguments)

    def visit_get_expr(self, expr: ast.expr.Get):
        obj = self._evaluate(expr.obj)
        if isinstance(obj, LoxInstance):
            return obj.get(expr.name)

        raise LoxRuntimeError(expr.name, "Only instances have properties.")

    def _evaluate(self, expr: ast.expr.Expr) -> object:
        return expr.accept(self)

    def _is_truthy(self, obj: object) -> bool:
        if obj == None:
            return False
        if type(obj) == bool:
            return obj
        return True

    def _is_equal(self, a, b) -> bool:
        if a == None and b == None:
            return True
        if a == None:
            return False
        if type(a) == bool and type(b) != bool:
            return False
        if type(b) == bool and type(a) != bool:
            return False
        return a == b

    def _check_number_operand(self, operator: Token, operand: object):
        if type(operand) == float:
            return
        raise LoxRuntimeError(operator, "Operand must be a number.")

    def _check_number_operands(self, operator: Token, left: object, right: object):
        if type(left) == float and type(right) == float:
            return
        raise LoxRuntimeError(operator, "Operands must be numbers.")

    def _check_number_or_string_operands(self, operator: Token, left: object, right: object):
        if type(left) == float and type(right) == float:
            return
        if type(left) == str and type(right) == str:
            return
        raise LoxRuntimeError(operator, "Operands must be two numbers or two strings.")

    def visit_expression_stmt(self, stmt: ast.stmt.Expression):
        self._evaluate(stmt.expression)

    def visit_function_stmt(self, stmt: ast.stmt.Function):
        function = Function(stmt, self._environment, False)
        self._environment.define(stmt.name.lexeme, function)

    def visit_if_stmt(self, stmt: ast.stmt.If):
        if self._is_truthy(self._evaluate(stmt.condition)):
            self._execute(stmt.then_branch)
        elif stmt.else_branch:
            self._execute(stmt.else_branch)

    def visit_print_stmt(self, stmt: ast.stmt.Print):
        value = self._evaluate(stmt.expression)
        print(self._stringify(value))

    def visit_return_stmt(self, stmt: ast.stmt.Return):
        value = None
        if stmt.value:
            value = self._evaluate(stmt.value)
        raise LoxReturn(value)

    def visit_var_stmt(self, stmt: ast.stmt.Var):
        value = None
        if stmt.initializer:
            value = self._evaluate(stmt.initializer)
        self._environment.define(stmt.name.lexeme, value)

    def visit_while_stmt(self, stmt: ast.stmt.While):
        while self._is_truthy(self._evaluate(stmt.condition)):
            self._execute(stmt.body)

    def visit_assign_expr(self, expr: ast.expr.Assign):
        value = self._evaluate(expr.value)

        distance = self._locals.get(expr)
        if distance != None:
            self._environment.assign_at(distance, expr.name, value)
        else:
            self._globals.assign(expr.name, value)

        return value

    def visit_variable_expr(self, expr: ast.expr.Variable):
        return self._look_up_variable(expr.name, expr)

    def _look_up_variable(self, name: Token, expr: ast.expr.Expr):
        distance = self._locals.get(expr)
        if distance != None:
            return self._environment.get_at(distance, name.lexeme)
        else:
            return self._globals.get(name)
