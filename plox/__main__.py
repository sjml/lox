import sys

from .lox import Lox
from .scanner import Scanner
from .parser import Parser
from .interpreter import Interpreter
from .resolver import Resolver

def run_file(path: str):
    raw = open(path, "r").read()
    run(raw)
    if Lox.had_error:
        sys.exit(65)
    if Lox.had_runtime_error:
        sys.exit(70)

def run_prompt():
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
            print("\n")
            break
        run(line)
        Lox.had_error = False

def run(source: str):
    scanner = Scanner(source)
    tokens = scanner._scan_tokens()

    try:
        parser = Parser(tokens)
        statements = parser.parse()
    except Parser.ParseError as pe:
        Lox.error(pe.token, pe.message)

    if Lox.had_error:
        return

    resolver = Resolver(Lox.interpreter)
    resolver.resolve(statements)

    if Lox.had_error:
        return

    Lox.interpreter.interpret(statements)


args = sys.argv[1:]
Lox.interpreter = Interpreter()
if len(args) > 1:
    print("Usage: plox [script]")
    sys.exit(64)
elif len(args) == 1:
    run_file(args[0])
else:
    run_prompt()
