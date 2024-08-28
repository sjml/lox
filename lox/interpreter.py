from typing import assert_never

from . import ast
from .scanner import Token, TokenType
from .lox import LoxRuntimeError, Lox

class Interpreter(ast.Expr.VisitorObject):
    def interpret(self, expression: ast.Expr):
        try:
            value = self._evaluate(expression)
            print(self._stringify(value))
        except LoxRuntimeError as lre:
            Lox.runtime_error(lre)

    def _stringify(self, obj: object) -> str:
        if obj == None:
            return "nil"
        if type(obj) == float:
            if obj.is_integer():
                return str(int(obj))
        return str(obj)


    def visit_literal_expr_object(self, expr: ast.Literal) -> object:
        return expr.value

    def visit_unary_expr_object(self, expr: ast.Unary) -> object:
        right = self._evaluate(expr.right)

        match expr.operator.type:
            case TokenType.MINUS:
                self._check_number_operand(expr.operator, right)
                return -float(right)
            case TokenType.BANG:
                return not self._is_truthy(right)
            case _:
                assert_never(expr.operator.type)

    def visit_grouping_expr_object(self, expr: ast.Grouping) -> object:
        return self._evaluate(expr.expression)

    def visit_binary_expr_object(self, expr: ast.Binary) -> object:
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


    def _evaluate(self, expr: ast.Expr) -> object:
        return expr.accept_object(self)

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
        return a == b

    def _check_number_operand(self, operator: Token, operand: object):
        if type(operand) == float:
            return
        raise LoxRuntimeError(operator, "Operand must be a number.")

    def _check_number_operands(self, operator: Token, left: object, right: object):
        if type(left) == float and type(right) == float:
            return
        raise LoxRuntimeError(operator, "Both operands must be numbers.")
    def _check_number_or_string_operands(self, operator: Token, left: object, right: object):
        if type(left) == float and type(right) == float:
            return
        if type(left) == str and type(right) == str:
            return
        raise LoxRuntimeError(operator, "Operands must be two numbers or two strings.")

