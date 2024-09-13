module vm;

import std.conv;
import std.stdio;
import std.string;
import std.conv;

import core.stdc.time;

import chunk : Chunk, OpCode;
import compiler : Compiler, FunctionType;
import value : Value, ValueType, printValue;
import lobj : ObjType, Obj, ObjString, ObjFunction, ObjNative, NativeFn;
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

static const FRAMES_MAX = 64;
static const STACK_MAX = FRAMES_MAX * (ubyte.max + 1);

struct CallFrame
{
    ObjFunction* fn;
    ubyte* ip;
    Value* slots;
}

static Value clockNative(int argCount, Value* args)
{
    return Value(to!double(clock()) / to!double(CLOCKS_PER_SEC));
}

struct VM
{
    private CallFrame[FRAMES_MAX] frames;
    private size_t frameCount;
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
        VM.instance.compiler = Compiler(FunctionType.Script, null);
        VM.instance.resetStack();

        VM.instance.defineNative("clock", &clockNative);
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
        this.frameCount = 0;
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

        for (int i = to!int(this.frameCount) - 1; i >= 0; i--)
        {
            CallFrame* frame = &this.frames[i];
            ObjFunction* fn = frame.fn;
            size_t inst = frame.ip - &fn.c.code[0] - 1;
            stderr.writef("[line %d] in ", fn.c.lineNumbers[inst]);
            if (fn.name == null)
            {
                stderr.writefln("script");
            }
            else
            {
                stderr.writefln("%s()", fn.name.chars);
            }
        }

        this.resetStack();
    }

    private void defineNative(string name, NativeFn fn)
    {
        this.push(Value(&ObjString.fromCopyOf(name).obj));
        this.push(Value(&ObjNative.create(fn).obj));
        this.globals.set(this.stack[0].obj.asString(), this.stack[1]);
        this.pop();
        this.pop();
    }

    static InterpretResult interpret(string source)
    {
        ObjFunction* cFn = VM.instance.compiler.compile(source);
        if (cFn == null)
        {
            return InterpretResult.CompileError;
        }
        VM.instance.push(Value(&cFn.obj));
        bool _ = VM.instance.call(cFn, 0);

        return VM.instance.run();
    }

    pragma(inline) private bool binaryNumericOperation(BinaryOperator op)
    {
        if (!(this.peek(0).valType == ValueType.Number) || !(this.peek(1)
                .valType == ValueType.Number))
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
        CallFrame* frame = &this.frames[this.frameCount - 1];

        pragma(inline) ubyte readByte()
        {
            return *frame.ip++;
        }

        pragma(inline) ushort readShort()
        {
            frame.ip += 2;
            return cast(ushort)(frame.ip[-2] << 8 | frame.ip[-1]);
        }

        pragma(inline) Value readConstant()
        {
            Chunk c = frame.fn.c;
            return frame.fn.c.constants.values[readByte()];
        }

        pragma(inline) ObjString* readString()
        {
            return readConstant().obj.asString();
        }

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
                lox_debug.disassembleInstruction(&frame.fn.c, frame.ip - frame.fn.c.code.ptr);
            }
            ubyte inst;
            switch (inst = readByte())
            {
            case OpCode.Constant:
                Value constant = readConstant();
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
            case OpCode.GetLocal:
                ubyte slot = readByte();
                this.push(frame.slots[slot]);
                break;
            case OpCode.SetLocal:
                ubyte slot = readByte();
                frame.slots[slot] = this.peek(0);
                break;
            case OpCode.GetGlobal:
                ObjString* name = readString();
                Value val;
                if (!this.globals.get(name, &val))
                {
                    this.runtimeError("Undefined variable '%s'.", fromStringz(name.chars));
                    return InterpretResult.RuntimeError;
                }
                this.push(val);
                break;
            case OpCode.DefineGlobal:
                ObjString* name = readString();
                this.globals.set(name, this.peek(0));
                this.pop();
                break;
            case OpCode.SetGlobal:
                ObjString* name = readString();
                if (this.globals.set(name, this.peek(0)))
                {
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
                else if (this.peek(0).valType == ValueType.Number
                        && (this.peek(1).valType == ValueType.Number))
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
                if (this.peek(0).valType != ValueType.Number)
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
            case OpCode.Jump:
                ushort offset = readShort();
                frame.ip += offset;
                break;
            case OpCode.JumpIfFalse:
                ushort offset = readShort();
                if (this.peek(0).isFalsey())
                {
                    frame.ip += offset;
                }
                break;
            case OpCode.Loop:
                ushort offset = readShort();
                frame.ip -= offset;
                break;
            case OpCode.Call:
                ubyte argCount = readByte();
                if (!this.callValue(this.peek(argCount), argCount))
                {
                    return InterpretResult.RuntimeError;
                }
                frame = &this.frames[this.frameCount - 1];
                break;
            case OpCode.Return:
                Value result = this.pop();
                this.frameCount -= 1;
                if (this.frameCount == 0)
                {
                    this.pop();
                    return InterpretResult.Ok;
                }
                this.stackTop = frame.slots;
                this.push(result);
                frame = &this.frames[this.frameCount - 1];
                break;
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

    private bool callValue(Value callee, int argCount)
    {
        if (callee.valType == ValueType.Obj)
        {
            Obj* callObj = callee.obj;
            auto s = callObj.asString();
            auto n = callObj.asNative();
            auto f = callObj.asFunction();
            switch (callObj.objType)
            {
            case ObjType.Function:
                ObjFunction* callFnObj = callObj.asFunction();
                return call(callFnObj, argCount);
                break;
            case ObjType.Native:
                ObjNative* nativeObj = callObj.asNative();
                NativeFn native = nativeObj.fn;
                Value result = native(argCount, this.stackTop - argCount);
                this.stackTop -= argCount + 1;
                this.push(result);
                return true;
            default:
                break;
            }
        }
        this.runtimeError("Can only call functions and classes.");
        return false;
    }

    private bool call(ObjFunction* fn, int argCount)
    {
        if (argCount != fn.arity)
        {
            this.runtimeError("Expected %d arguments but got %d.", fn.arity, argCount);
            return false;
        }

        if (this.frameCount == FRAMES_MAX)
        {
            this.runtimeError("Stack overflow.");
            return false;
        }

        CallFrame* frame = &this.frames[this.frameCount++];
        frame.fn = fn;
        frame.ip = &fn.c.code[0];
        frame.slots = this.stackTop - argCount - 1;
        return true;
    }
}
