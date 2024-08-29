from . import ast
from .environment import Environment
from .callable import Callable
from .ret import LoxReturn
from .klass import LoxInstance

class Function(Callable):
    def __init__(self, declaration: ast.stmt.Function, closure: Environment, is_initializer: bool) -> None:
        self._declaration = declaration
        self._closure = closure
        self._is_initializer = is_initializer

    def bind(self, instance: LoxInstance):
        env = Environment(self._closure)
        env.define("this", instance)
        return Function(self._declaration, env, self._is_initializer)

    def arity(self) -> int:
        return len(self._declaration.params)

    def call(self, interpreter, arguments: list[object]) -> object:
        environment = Environment(self._closure)
        for i in range(len(self._declaration.params)):
            environment.define(self._declaration.params[i].lexeme, arguments[i])

        try:
            interpreter.execute_block(self._declaration.body, environment)
        except LoxReturn as lr:
            if self._is_initializer:
                return self._closure.get_at(0, "this")
            return lr.value

        if self._is_initializer:
            return self._closure.get_at(0, "this")

        return None

    def __str__(self) -> str:
        return f"<fn {self._declaration.name.lexeme}>"

