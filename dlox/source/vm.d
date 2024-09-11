module vm;

import std.stdio;
import std.string;

import chunk : Chunk, OpCode;
import compiler : Compiler;
import value : Value, ValueType, printValue;
import lobj : ObjType, Obj, ObjString;
import table : Table;
import lox_debug;

enum InterpretResult
{
    Ok,
    CompileError,
    RuntimeError,
}

enum BinaryOperator
{
    Add,
    Subtract,
    Multiply,
    Divide,
    GreaterThan,
    LessThan,
}

static const STACK_MAX = 256;

struct VM
{
    Chunk* chunk = null;
    private ubyte* ip = null;
    private Value[STACK_MAX] stack;
    private Value* stackTop = null;
    Table globals;
    Table strings;
    Obj* objects = null;
    private Compiler compiler;
    static VM* instance = null;

    static void setup()
    {
        VM.instance = new VM();
        VM.instance.resetStack();
    }

    static void teardown()
    {
        VM.instance.globals.free();
        VM.instance.strings.free();
        VM.instance.freeObjects();
        VM.instance = null;
    }

    private void resetStack()
    {
        this.stackTop = stack.ptr;
    }

    private void freeObjects()
    {
        Obj* o = this.objects;
        while (o != null)
        {
            Obj* next = o.next;
            o.free();
            o = next;
        }
    }

    private void runtimeError(T...)(T args)
    {
        stderr.writefln(args);

        size_t inst = this.ip - this.chunk.code.ptr - 1;
        size_t line = this.chunk.line_numbers[inst];
        stderr.writefln("[line %d] in script", line);
        this.resetStack();
    }

    static InterpretResult interpret(string source)
    {
        Chunk c;

        if (!VM.instance.compiler.compile(source, &c))
        {
            c.free();
            return InterpretResult.CompileError;
        }

        VM.instance.chunk = &c;
        VM.instance.ip = VM.instance.chunk.code.ptr;

        InterpretResult res = VM.instance.run();

        c.free();
        VM.instance.chunk = null;
        VM.instance.ip = null;

        return res;
    }

    pragma(inline) private ubyte readByte()
    {
        return *this.ip++;
    }

    pragma(inline) private Value readConstant()
    {
        return this.chunk.constants.values[this.readByte];
    }

    pragma(inline) private ObjString* readString() {
        return this.readConstant().obj.asString();
    }

    pragma(inline) private bool binaryNumericOperation(BinaryOperator op)
    {
        if (!(this.peek(0).val_type == ValueType.Number) || !(this.peek(1)
                .val_type == ValueType.Number))
        {
            this.runtimeError("Operands must be numbers.");
            return false;
        }

        double b = this.pop().number;
        double a = this.pop().number;
        switch (op)
        {
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

    pragma(inline) private void concatenateStrings()
    {
        ObjString* b = pop().obj.asString();
        ObjString* a = pop().obj.asString();

        size_t newLen = a.length + b.length;
        ObjString* newStr = ObjString.allocateString(newLen, 0);
        for (size_t idx = 0; idx < a.length; idx++)
        {
            newStr.chars[idx] = a.chars[idx];
        }
        for (size_t idx = 0; idx < b.length; idx++)
        {
            newStr.chars[idx + a.length] = b.chars[idx];
        }
        newStr.chars[newLen] = '\0';
        newStr.hash = ObjString.hashString(cast(immutable(char)*) newStr.chars, newLen);

        push(Value(cast(Obj*) newStr));
    }

    private InterpretResult run()
    {
        while (true)
        {
            version (DebugTraceExecution)
            {
                writef("          ");
                for (Value* slot = this.stack.ptr; slot < this.stackTop; slot++)
                {
                    writef("[ ");
                    printValue(*slot);
                    writef(" ]");
                }
                writefln("");
                lox_debug.disassembleInstruction(this.chunk, this.ip - this.chunk.code.ptr);
            }
            ubyte inst;
            switch (inst = this.readByte)
            {
            case OpCode.Constant:
                Value constant = this.readConstant();
                this.push(constant);
                break;
            case OpCode.Nil:
                this.push(Value.nil());
                break;
            case OpCode.True:
                this.push(Value(true));
                break;
            case OpCode.False:
                this.push(Value(false));
                break;
            case OpCode.Pop:
                this.pop();
                break;
            case OpCode.GetGlobal:
                ObjString* name = this.readString();
                Value val;
                if (!this.globals.get(name, &val)) {
                    this.runtimeError("Undefined variable '%s'.", fromStringz(name.chars));
                    return InterpretResult.RuntimeError;
                }
                this.push(val);
                break;
            case OpCode.DefineGlobal:
                ObjString* name = this.readString();
                this.globals.set(name, this.peek(0));
                this.pop();
                break;
            case OpCode.SetGlobal:
                ObjString* name = this.readString();
                if (this.globals.set(name, this.peek(0))) {
                    this.globals.remove(name);
                    this.runtimeError("Undefined variable '%s'.", fromStringz(name.chars));
                    return InterpretResult.RuntimeError;
                }
                break;
            case OpCode.Equal:
                Value b = this.pop();
                Value a = this.pop();
                push(Value(a.equals(b)));
                break;
            case OpCode.Greater:
                if (!this.binaryNumericOperation(BinaryOperator.GreaterThan))
                {
                    return InterpretResult.RuntimeError;
                }
                break;
            case OpCode.Less:
                if (!this.binaryNumericOperation(BinaryOperator.LessThan))
                {
                    return InterpretResult.RuntimeError;
                }
                break;
            case OpCode.Add:
                if (this.peek(0).isObjType(ObjType.String)
                        && (this.peek(1).isObjType(ObjType.String)))
                {
                    this.concatenateStrings();
                }
                else if (this.peek(0).val_type == ValueType.Number
                        && (this.peek(1).val_type == ValueType.Number))
                {
                    double b = this.pop().number;
                    double a = this.pop().number;
                    this.push(Value(a + b));
                }
                else
                {
                    this.runtimeError("Operands must be two numbers or two strings.");
                    return InterpretResult.RuntimeError;
                }
                break;
            case OpCode.Subtract:
                if (!this.binaryNumericOperation(BinaryOperator.Subtract))
                {
                    return InterpretResult.RuntimeError;
                }
                break;
            case OpCode.Multiply:
                if (!this.binaryNumericOperation(BinaryOperator.Multiply))
                {
                    return InterpretResult.RuntimeError;
                }
                break;
            case OpCode.Divide:
                if (!this.binaryNumericOperation(BinaryOperator.Divide))
                {
                    return InterpretResult.RuntimeError;
                }
                break;
            case OpCode.Not:
                this.push(Value(pop().isFalsey()));
                break;
            case OpCode.Negate:
                if (this.peek(0).val_type != ValueType.Number)
                {
                    this.runtimeError("Operand must be a number.");
                    return InterpretResult.RuntimeError;
                }
                this.push(Value(-this.pop().number));
                break;
            case OpCode.Print:
                printValue(this.pop());
                writefln("");
                break;
            case OpCode.Return:
                return InterpretResult.Ok;
            default:
                stderr.writefln("ERROR: Unknown opcode '%d'", inst);
                break;
            }
        }
    }

    private void push(Value val)
    {
        *this.stackTop = val;
        this.stackTop++;
    }

    private Value pop()
    {
        this.stackTop--;
        return *this.stackTop;
    }

    private Value peek(int distance)
    {
        return this.stackTop[-1 - distance];
    }
}
