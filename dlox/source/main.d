import std.stdio;
import std.file;

import vm : VM, InterpretResult;
import chunk : Chunk, OpCode;
import lox_debug;

int main(string[] args)
{
    VM.setup();
    scope(exit) VM.teardown();

    switch (args.length) {
        case 1:
            return repl();
            break;
        case 2:
            return runFile(args[1]);
            break;
        default:
            writefln("Usage: dlox [path]");
            return 64;
    }

    return 0;
}

int repl() {
    while (true) {
        writef("> ");
        string line = stdin.readln();
        if (line.length == 0) {
            writef("\nExiting...\n");
            break;
        }
        VM.interpret(line);
    }
    return 0;
}

int runFile(string path) {
    string source = readText(path);
    InterpretResult result = VM.interpret(source);

    switch (result) {
        case InterpretResult.CompileError:
            return 65;
        case InterpretResult.RuntimeError:
            return 70;
        case InterpretResult.Ok:
            return 0;
        default:
            assert(0); // unreachable
    }
}
