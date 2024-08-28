from __future__ import annotations

from .token import Token
from .lox import LoxRuntimeError

class Environment:
    def __init__(self, enclosing: Environment|None = None) -> None:
        self._values: dict[str,object] = {}
        self._enclosing = enclosing

    def define(self, name: str, value: object):
        self._values[name] = value

    def get(self, name: Token) -> object:
        if name.lexeme in self._values:
            return self._values[name.lexeme]

        if self._enclosing:
            return self._enclosing.get(name)

        raise LoxRuntimeError(name, f"Undefined variable '{name.lexeme}'.")

    def assign(self, name: Token, value: object):
        if name.lexeme in self._values:
            self._values[name.lexeme] = value
            return

        if self._enclosing:
            self._enclosing.assign(name, value)
            return

        raise LoxRuntimeError(name, f"Undefined variable '{name.lexeme}'.")


