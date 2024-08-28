from . import ast
from .environment import Environment
from .callable import Callable
from .ret import LoxReturn

class Function(Callable):
    def __init__(self, declaration: ast.stmt.Function, closure: Environment) -> None:
        self._declaration = declaration
        self._closure = closure

    def arity(self) -> int:
        return len(self._declaration.params)

    def call(self, interpreter, arguments: list[object]) -> object:
        environment = Environment(self._closure)
        for i in range(len(self._declaration.params)):
            environment.define(self._declaration.params[i].lexeme, arguments[i])

        try:
            interpreter.execute_block(self._declaration.body, environment)
        except LoxReturn as lr:
            return lr.value
        return None

    def __str__(self) -> str:
        return f"<fn {self._declaration.name.lexeme}>"

