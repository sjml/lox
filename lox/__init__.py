import sys

from .scanner import Scanner

class Lox:
    had_error = False

    def main(self, args: list[str]):
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
        if self.had_error:
            sys.exit(65)

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
            self.had_error = False

    def run(self, source: str):
        scanner = Scanner(source)
        tokens = scanner.scan_tokens()

        for token in tokens:
            print(token)

    def error(line: int, message: str):
        Lox.report(line, "", message)

    def report(line: int, where: str, message: str):
        sys.stderr.write(f"[line {line}] Error{where}: {message}\n")
        Lox.had_error = True
