from __future__ import annotations
import sys

from .token import Token, TokenType

class Lox:
    had_error = False
    had_runtime_error = False

    def error(problem: int|Token, message: str):
        if type(problem) == int:
            Lox.report(problem, "", message)
        elif type(problem) == Token:
            if problem.type == TokenType.EOF:
                Lox.report(problem.line, " at end", message)
            else:
                Lox.report(problem.line, f" at '{problem.lexeme}'", message)

    def runtime_error(error: LoxRuntimeError):
        sys.stderr.write(f"{error.message}\n[line {error.token.line}]\n")
        Lox.had_runtime_error = True

    def report(line: int, where: str, message: str):
        sys.stderr.write(f"[line {line}] Error{where}: {message}\n")
        Lox.had_error = True

class LoxRuntimeError(RuntimeError):
    def __init__(self, token: Token, message: str) -> None:
        super().__init__()
        self.token = token
        self.message = message
