import sys

class Lox:
    had_error = False

    def error(line: int, message: str):
        Lox.report(line, "", message)

    def report(line: int, where: str, message: str):
        sys.stderr.write(f"[line {line}] Error{where}: {message}\n")
        had_error = True
