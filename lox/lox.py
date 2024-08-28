import sys

from .token import Token, TokenType

class Lox:
    had_error = False

    def error(problem: int|Token, message: str):
        if type(problem) == int:
            Lox.report(problem, "", message)
        elif type(problem) == Token:
            if problem.type == TokenType.EOF:
                Lox.report(problem.line, " at end", message)
            else:
                Lox.report(problem.line, f" at '{problem.lexeme}'", message)

    def report(line: int, where: str, message: str):
        Lox.had_error = True
        sys.stderr.write(f"[line {line}] Error{where}: {message}\n")
