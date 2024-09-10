module vm;

import std.stdio;

import chunk : Chunk, OpCode;
import compiler : Compiler;
import value : Value, printValue;
import lox_debug;

enum InterpretResult {
    Ok,
    CompileError,
    RuntimeError,
}

enum BinaryOperator {
    Add,
    Subtract,
    Multiply,
    Divide,
}

static const STACK_MAX = 256;

struct VM {
    Chunk* chunk = null;
    private ubyte* ip = null;
    private Value[STACK_MAX] stack;
    private Value* stackTop = null;
    private Compiler compiler;
    private static VM* instance = null;

    static void setup() {
        VM.instance = new VM();
        VM.instance.resetStack();
    }

    static void teardown() {
        VM.instance = null;
    }

    private void resetStack() {
        this.stackTop = stack.ptr;
    }

    static InterpretResult interpret(string source) {
        VM.instance.compiler.compile(source);
        return InterpretResult.Ok;
    }

    pragma(inline)
    private ubyte readByte() {
        return *this.ip++;
    }

    pragma(inline)
    private Value readConstant() {
        return this.chunk.constants.values[this.readByte];
    }

    pragma(inline)
    private void binaryOperation(BinaryOperator op) {
        Value b = this.pop();
        Value a = this.pop();
        switch (op) {
            case BinaryOperator.Add:
                this.push(a + b);
                break;
            case BinaryOperator.Subtract:
                this.push(a - b);
                break;
            case BinaryOperator.Multiply:
                this.push(a * b);
                break;
            case BinaryOperator.Divide:
                this.push(a / b);
                break;
            default:
                assert(0); // unreachable
        }
    }

    private InterpretResult run() {
        while (true) {
            version(DebugTraceExecution) {
                writef("          ");
                for (Value* slot = this.stack.ptr; slot < this.stackTop; slot++) {
                    writef("[ ");
                    printValue(*slot);
                    writef(" ]");
                }
                writefln("");
                lox_debug.disassembleInstruction(this.chunk, this.ip - this.chunk.code.ptr);
            }
            ubyte inst;
            switch (inst = this.readByte) {
                case OpCode.Constant:
                    Value constant = this.readConstant();
                    this.push(constant);
                    break;
                case OpCode.Add: this.binaryOperation(BinaryOperator.Add); break;
                case OpCode.Subtract: this.binaryOperation(BinaryOperator.Subtract); break;
                case OpCode.Multiply: this.binaryOperation(BinaryOperator.Multiply); break;
                case OpCode.Divide: this.binaryOperation(BinaryOperator.Divide); break;
                case OpCode.Negate:
                    this.push(-this.pop());
                    break;
                case OpCode.Return:
                    printValue(this.pop());
                    writefln("");
                    return InterpretResult.Ok;
                default:
                    stderr.writefln("ERROR: Unknown opcode '%d'", inst);
                    break;
            }
        }
    }

    private void push(Value val) {
        *this.stackTop = val;
        this.stackTop++;
    }

    private Value pop() {
        this.stackTop--;
        return *this.stackTop;
    }
}
