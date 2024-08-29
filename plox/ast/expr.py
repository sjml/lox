# This file was automatically generated by ./tool/generate_ast.py

from __future__ import annotations
import abc

from ..token import Token

class Expr:
    @abc.abstractmethod
    def accept(self, visitor: Expr):
        pass

class ExprVisitor(abc.ABC):
    @abc.abstractmethod
    def visit_assign_expr(self, expr: Assign):
        pass

    @abc.abstractmethod
    def visit_binary_expr(self, expr: Binary):
        pass

    @abc.abstractmethod
    def visit_call_expr(self, expr: Call):
        pass

    @abc.abstractmethod
    def visit_get_expr(self, expr: Get):
        pass

    @abc.abstractmethod
    def visit_grouping_expr(self, expr: Grouping):
        pass

    @abc.abstractmethod
    def visit_literal_expr(self, expr: Literal):
        pass

    @abc.abstractmethod
    def visit_logical_expr(self, expr: Logical):
        pass

    @abc.abstractmethod
    def visit_set_expr(self, expr: Set):
        pass

    @abc.abstractmethod
    def visit_super_expr(self, expr: Super):
        pass

    @abc.abstractmethod
    def visit_this_expr(self, expr: This):
        pass

    @abc.abstractmethod
    def visit_unary_expr(self, expr: Unary):
        pass

    @abc.abstractmethod
    def visit_variable_expr(self, expr: Variable):
        pass


class Assign(Expr):
    def __init__(self, name: Token, value: Expr):
        self.name: Token = name
        self.value: Expr = value

    def accept(self, visitor: Expr.Visitor):
        return visitor.visit_assign_expr(self)

class Binary(Expr):
    def __init__(self, left: Expr, operator: Token, right: Expr):
        self.left: Expr = left
        self.operator: Token = operator
        self.right: Expr = right

    def accept(self, visitor: Expr.Visitor):
        return visitor.visit_binary_expr(self)

class Call(Expr):
    def __init__(self, callee: Expr, paren: Token, arguments: list[Expr]):
        self.callee: Expr = callee
        self.paren: Token = paren
        self.arguments: list[Expr] = arguments

    def accept(self, visitor: Expr.Visitor):
        return visitor.visit_call_expr(self)

class Get(Expr):
    def __init__(self, obj: Expr, name: Token):
        self.obj: Expr = obj
        self.name: Token = name

    def accept(self, visitor: Expr.Visitor):
        return visitor.visit_get_expr(self)

class Grouping(Expr):
    def __init__(self, expression: Expr):
        self.expression: Expr = expression

    def accept(self, visitor: Expr.Visitor):
        return visitor.visit_grouping_expr(self)

class Literal(Expr):
    def __init__(self, value):
        self.value = value

    def accept(self, visitor: Expr.Visitor):
        return visitor.visit_literal_expr(self)

class Logical(Expr):
    def __init__(self, left: Expr, operator: Token, right: Expr):
        self.left: Expr = left
        self.operator: Token = operator
        self.right: Expr = right

    def accept(self, visitor: Expr.Visitor):
        return visitor.visit_logical_expr(self)

class Set(Expr):
    def __init__(self, obj: Expr, name: Token, value: Expr):
        self.obj: Expr = obj
        self.name: Token = name
        self.value: Expr = value

    def accept(self, visitor: Expr.Visitor):
        return visitor.visit_set_expr(self)

class Super(Expr):
    def __init__(self, keyword: Token, method: Token):
        self.keyword: Token = keyword
        self.method: Token = method

    def accept(self, visitor: Expr.Visitor):
        return visitor.visit_super_expr(self)

class This(Expr):
    def __init__(self, keyword: Token):
        self.keyword: Token = keyword

    def accept(self, visitor: Expr.Visitor):
        return visitor.visit_this_expr(self)

class Unary(Expr):
    def __init__(self, operator: Token, right: Expr):
        self.operator: Token = operator
        self.right: Expr = right

    def accept(self, visitor: Expr.Visitor):
        return visitor.visit_unary_expr(self)

class Variable(Expr):
    def __init__(self, name: Token):
        self.name: Token = name

    def accept(self, visitor: Expr.Visitor):
        return visitor.visit_variable_expr(self)


