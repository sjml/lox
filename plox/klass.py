from __future__ import annotations

from .callable import Callable
from .token import Token
from .lox import LoxRuntimeError

class LoxClass(Callable):
    def __init__(self, name: str, methods: dict) -> None:
        self.name = name
        self._methods = methods

    def find_method(self, name: str):
        if name in self._methods:
            return self._methods[name]

        return None

    def call(self, interpreter, arguments: list[object]) -> object:
        instance = LoxInstance(self)
        initializer = self.find_method("init")
        if initializer:
            initializer.bind(instance).call(interpreter, arguments)
        return instance

    def arity(self) -> int:
        initializer = self.find_method("init")
        if not initializer:
            return 0
        return initializer.arity()

    def __str__(self) -> str:
        return self.name

class LoxInstance:
    def __init__(self, klass: LoxClass) -> None:
        self._klass = klass
        self._fields: dict[str,object] = {}

    def get(self, name: Token):
        if name.lexeme in self._fields:
            return self._fields.get(name.lexeme)

        method = self._klass.find_method(name.lexeme)
        if method:
            return method.bind(self)

        raise LoxRuntimeError(name, f"Undefined property '{name.lexeme}'.")

    def set(self, name: Token, value: object):
        self._fields[name.lexeme] = value

    def __str__(self) -> str:
        return f"{self._klass.name} instance"
