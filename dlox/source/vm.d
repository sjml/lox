module vm;

import std.stdio;

import chunk : Chunk, OpCode;
import compiler : Compiler;
import value : Value, ValueType, printValue;
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
    GreaterThan,
    LessThan,
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

    private void runtimeError(T...)(T args) {
        writefln(args);

        size_t inst = this.ip - this.chunk.code.ptr - 1;
        size_t line = this.chunk.line_numbers[inst];
        stderr.writefln("[line %d] in script", line);
        this.resetStack();
    }

    static InterpretResult interpret(string source) {
        Chunk c;

        if (!VM.instance.compiler.compile(source, &c)) {
            c.free();
            return InterpretResult.CompileError;
        }

        VM.instance.chunk = &c;
        VM.instance.ip = VM.instance.chunk.code.ptr;

        InterpretResult res = VM.instance.run();

        c.free();
        VM.instance.chunk = null;
        VM.instance.ip = null;

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
    private bool binaryOperation(BinaryOperator op) {
        if (
               (!this.peek(0).val_type == ValueType.Number)
            || (!this.peek(1).val_type == ValueType.Number)
        ) {
            this.runtimeError("Operands must be numbers.");
            return false;
        }

        double b = this.pop().number;
        double a = this.pop().number;
        switch (op) {
            case BinaryOperator.GreaterThan:
                this.push(Value(a > b));
                break;
            case BinaryOperator.LessThan:
                this.push(Value(a < b));
                break;
            case BinaryOperator.Add:
                this.push(Value(a + b));
                break;
            case BinaryOperator.Subtract:
                this.push(Value(a - b));
                break;
            case BinaryOperator.Multiply:
                this.push(Value(a * b));
                break;
            case BinaryOperator.Divide:
                this.push(Value(a / b));
                break;
            default:
                assert(false); // unreachable
        }
        return true;
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
                case OpCode.Nil: this.push(Value.nil()); break;
                case OpCode.True: this.push(Value(true)); break;
                case OpCode.False: this.push(Value(false)); break;
                case OpCode.Equal:
                    Value b = this.pop();
                    Value a = this.pop();
                    push(Value(a.equals(b)));
                    break;
                case OpCode.Greater:
                    if (!this.binaryOperation(BinaryOperator.GreaterThan)) {
                        return InterpretResult.RuntimeError;
                    }
                    break;
                case OpCode.Less:
                    if (!this.binaryOperation(BinaryOperator.LessThan)) {
                        return InterpretResult.RuntimeError;
                    }
                    break;
                case OpCode.Add:
                    if (!this.binaryOperation(BinaryOperator.Add)) {
                        return InterpretResult.RuntimeError;
                    }
                    break;
                case OpCode.Subtract:
                    if (!this.binaryOperation(BinaryOperator.Subtract)) {
                        return InterpretResult.RuntimeError;
                    }
                    break;
                case OpCode.Multiply:
                    if (!this.binaryOperation(BinaryOperator.Multiply)) {
                        return InterpretResult.RuntimeError;
                    }
                    break;
                case OpCode.Divide:
                    if (!this.binaryOperation(BinaryOperator.Divide)) {
                        return InterpretResult.RuntimeError;
                    }
                    break;
                case OpCode.Not:
                    this.push(Value(pop().isFalsey()));
                    break;
                case OpCode.Negate:
                    if (!this.peek(0).val_type == ValueType.Number) {
                        this.runtimeError("Operand must be a number.");
                        return InterpretResult.RuntimeError;
                    }
                    this.push(Value(-this.pop().number));
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

    private Value peek(int distance) {
        return this.stackTop[-1 - distance];
    }
}
