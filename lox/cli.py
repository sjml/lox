import sys

from .lox import Lox
from .scanner import Scanner
from .parser import Parser
from .interpreter import Interpreter

class CLI:
    def main(self, args: list[str]):
        self.interpreter = Interpreter()
        if len(args) > 1:
            print("Usage: plox [script]")
            sys.exit(64)
        elif len(args) == 1:
            self.run_file(args[0])
        else:
            self.run_prompt()

    def run_file(self, path: str):
        raw = open(path, "r").read()
        self.run(raw)
        if Lox.had_error:
            sys.exit(65)
        if Lox.had_runtime_error:
            sys.exit(70)

    def run_prompt(self):
        def get_line():
            try:
                line = input("> ")
                return line
            except EOFError:
                return None
            except KeyboardInterrupt:
                print()
                return get_line()

        while True:
            line = get_line()
            if not line:
                print("\nExiting lox!")
                break
            self.run(line)
            Lox.had_error = False

    def run(self, source: str):
        scanner = Scanner(source)
        tokens = scanner._scan_tokens()

        parser = Parser(tokens)
        expression = parser.parse()

        if Lox.had_error:
            return

        self.interpreter.interpret(expression)
