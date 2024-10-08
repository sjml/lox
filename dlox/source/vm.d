module vm;

import std.conv;
import std.stdio;
import std.string;
import std.conv;

import core.stdc.time;

import chunk : Chunk, OpCode;
import compiler : Compiler, FunctionType;
import value;
import memory : freeGrayStack;
import lobj;
import table : Table;
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

static const FRAMES_MAX = 64;
static const STACK_MAX = FRAMES_MAX * (ubyte.max + 1);

struct CallFrame {
    ObjClosure* closure;
    ubyte* ip;
    Value* slots;
}

static Value clockNative(int argCount, Value* args) {
    return Value(to!double(clock()) / to!double(CLOCKS_PER_SEC));
}

struct VM {
    CallFrame[FRAMES_MAX] frames;
    size_t frameCount;
    Value[STACK_MAX] stack;
    Value* stackTop = null;
    Table globals;
    Table strings;
    ObjString* initString;
    ObjUpvalue* openUpvalues;
    size_t bytesAllocated = 0;
    size_t nextGC = 1024 * 1024;
    Obj* objects = null;
    size_t grayCount = 0;
    size_t grayCapacity = 0;
    Obj** grayStack = null;
    Compiler compiler;
    Compiler* currentCompiler;
    static VM* instance = null;

    static void setup() {
        VM.instance = new VM();
        VM.instance.compiler = Compiler(FunctionType.Script, null);
        VM.instance.currentCompiler = &VM.instance.compiler;
        VM.instance.resetStack();

        VM.instance.initString = null;
        VM.instance.initString = ObjString.fromCopyOf("init");
        VM.instance.defineNative("clock", &clockNative);
    }

    static void teardown() {
        VM.instance.globals.free();
        VM.instance.strings.free();
        // VM.instance.initString.obj.free(); // this gets freed with the objects, right?
        VM.instance.freeObjects();
        freeGrayStack();
        VM.instance = null;
    }

    private void resetStack() {
        this.stackTop = stack.ptr;
        this.frameCount = 0;
        this.openUpvalues = null;
    }

    private void freeObjects() {
        Obj* o = this.objects;
        while (o != null) {
            Obj* next = o.next;
            o.free();
            o = next;
        }
    }

    private void runtimeError(T...)(T args) {
        stderr.writefln(args);

        for (int i = to!int(this.frameCount) - 1; i >= 0; i--) {
            CallFrame* frame = &this.frames[i];
            ObjFunction* fn = frame.closure.fn;
            size_t inst = frame.ip - &fn.c.code[0] - 1;
            stderr.writef("[line %d] in ", fn.c.lineNumbers[inst]);
            if (fn.name == null) {
                stderr.writefln("script");
            } else {
                stderr.writefln("%s()", fn.name.chars);
            }
        }

        this.resetStack();
    }

    private void defineNative(string name, NativeFn fn) {
        this.push(Value(&ObjString.fromCopyOf(name).obj));
        this.push(Value(&ObjNative.create(fn).obj));
        this.globals.set(this.stack[0].obj.as!ObjString(), this.stack[1]);
        this.pop();
        this.pop();
    }

    static InterpretResult interpret(string source) {
        ObjFunction* cFn = VM.instance.compiler.compile(source);
        if (cFn == null) {
            return InterpretResult.CompileError;
        }
        VM.instance.push(Value(&cFn.obj));
        ObjClosure* closure = ObjClosure.create(cFn);
        VM.instance.pop();
        VM.instance.push(Value(&closure.obj));
        bool _ = VM.instance.call(closure, 0);

        return VM.instance.run();
    }

    pragma(inline) private bool binaryNumericOperation(BinaryOperator op) {
        if (!(this.peek(0).isNumber()) || !(this.peek(1).isNumber())) {
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

    pragma(inline) private void concatenateStrings() {
        ObjString* b = this.peek(0).obj.as!ObjString();
        ObjString* a = this.peek(1).obj.as!ObjString();

        size_t newLen = a.length + b.length;
        ObjString* newStr = ObjString.allocateString(newLen, 0);
        for (size_t idx = 0; idx < a.length; idx++) {
            newStr.chars[idx] = a.chars[idx];
        }
        for (size_t idx = 0; idx < b.length; idx++) {
            newStr.chars[idx + a.length] = b.chars[idx];
        }
        newStr.chars[newLen] = '\0';
        newStr.hash = ObjString.hashString(cast(immutable(char)*) newStr.chars, newLen);

        this.pop();
        this.pop();
        this.push(Value(cast(Obj*) newStr));
    }

    private InterpretResult run() {
        CallFrame* frame = &this.frames[this.frameCount - 1];

        pragma(inline) ubyte readByte() {
            return *frame.ip++;
        }

        pragma(inline) ushort readShort() {
            frame.ip += 2;
            return cast(ushort)(frame.ip[-2] << 8 | frame.ip[-1]);
        }

        pragma(inline) Value readConstant() {
            return frame.closure.fn.c.constants.values[readByte()];
        }

        pragma(inline) ObjString* readString() {
            return readConstant().obj.as!ObjString();
        }

        while (true) {
            version (DebugTraceExecution) {
                writef("          ");
                for (Value* slot = this.stack.ptr; slot < this.stackTop; slot++) {
                    writef("[ ");
                    slot.print();
                    writef(" ]");
                }
                writeln("");
                lox_debug.disassembleInstruction(&frame.closure.fn.c,
                        frame.ip - frame.closure.fn.c.code.ptr);
            }
            ubyte inst;
            switch (inst = readByte()) {
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
                if (!this.globals.get(name, &val)) {
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
                if (this.globals.set(name, this.peek(0))) {
                    this.globals.remove(name);
                    this.runtimeError("Undefined variable '%s'.", fromStringz(name.chars));
                    return InterpretResult.RuntimeError;
                }
                break;
            case OpCode.GetUpvalue:
                ubyte slot = readByte();
                this.push(*frame.closure.upvalues[slot].location);
                break;
            case OpCode.SetUpvalue:
                ubyte slot = readByte();
                *frame.closure.upvalues[slot].location = this.peek(0);
                break;
            case OpCode.GetProperty:
                if (!(this.peek(0).isObj() && this.peek(0).obj.objType == ObjType.Instance)) {
                    runtimeError("Only instances have properties.");
                    return InterpretResult.RuntimeError;
                }
                ObjInstance* ins = this.peek(0).obj.as!ObjInstance();
                ObjString* name = readString();
                Value val;
                if (ins.fields.get(name, &val)) {
                    this.pop();
                    this.push(val);
                    break;
                }

                if (!this.bindMethod(ins.klass, name)) {
                    return InterpretResult.RuntimeError;
                }
                break;
            case OpCode.SetProperty:
                if (!(this.peek(1).isObj() && this.peek(1).obj.objType == ObjType.Instance)) {
                    this.runtimeError("Only instances have fields.");
                    return InterpretResult.RuntimeError;
                }
                ObjInstance* ins = this.peek(1).obj.as!ObjInstance();
                ins.fields.set(readString(), peek(0));
                Value val = this.pop();
                this.pop();
                this.push(val);
                break;
            case OpCode.GetSuper:
                ObjString* name = readString();
                ObjClass* superclass = pop().obj.as!ObjClass();
                if (!this.bindMethod(superclass, name)) {
                    return InterpretResult.RuntimeError;
                }
                break;
            case OpCode.Equal:
                Value b = this.pop();
                Value a = this.pop();
                push(Value(a.equals(b)));
                break;
            case OpCode.Greater:
                if (!this.binaryNumericOperation(BinaryOperator.GreaterThan)) {
                    return InterpretResult.RuntimeError;
                }
                break;
            case OpCode.Less:
                if (!this.binaryNumericOperation(BinaryOperator.LessThan)) {
                    return InterpretResult.RuntimeError;
                }
                break;
            case OpCode.Add:
                if (this.peek(0).isObjType(ObjType.String)
                        && (this.peek(1).isObjType(ObjType.String))) {
                    this.concatenateStrings();
                } else if (this.peek(0).isNumber() && (this.peek(1).isNumber())) {
                    double b = this.pop().number;
                    double a = this.pop().number;
                    this.push(Value(a + b));
                } else {
                    this.runtimeError("Operands must be two numbers or two strings.");
                    return InterpretResult.RuntimeError;
                }
                break;
            case OpCode.Subtract:
                if (!this.binaryNumericOperation(BinaryOperator.Subtract)) {
                    return InterpretResult.RuntimeError;
                }
                break;
            case OpCode.Multiply:
                if (!this.binaryNumericOperation(BinaryOperator.Multiply)) {
                    return InterpretResult.RuntimeError;
                }
                break;
            case OpCode.Divide:
                if (!this.binaryNumericOperation(BinaryOperator.Divide)) {
                    return InterpretResult.RuntimeError;
                }
                break;
            case OpCode.Not:
                this.push(Value(pop().isFalsey()));
                break;
            case OpCode.Negate:
                if (!this.peek(0).isNumber()) {
                    this.runtimeError("Operand must be a number.");
                    return InterpretResult.RuntimeError;
                }
                this.push(Value(-this.pop().number));
                break;
            case OpCode.Print:
                Value p = this.pop();
                p.print();
                writeln("");
                break;
            case OpCode.Jump:
                ushort offset = readShort();
                frame.ip += offset;
                break;
            case OpCode.JumpIfFalse:
                ushort offset = readShort();
                if (this.peek(0).isFalsey()) {
                    frame.ip += offset;
                }
                break;
            case OpCode.Loop:
                ushort offset = readShort();
                frame.ip -= offset;
                break;
            case OpCode.Call:
                int argCount = readByte();
                if (!this.callValue(this.peek(argCount), argCount)) {
                    return InterpretResult.RuntimeError;
                }
                frame = &this.frames[this.frameCount - 1];
                break;
            case OpCode.Invoke:
                ObjString* method = readString();
                int argCount = readByte();
                if (!invoke(method, argCount)) {
                    return InterpretResult.RuntimeError;
                }
                frame = &VM.instance.frames[VM.instance.frameCount - 1];
                break;
            case OpCode.SuperInvoke:
                ObjString* method = readString();
                int argCount = readByte();
                ObjClass* superclass = pop().obj.as!ObjClass();
                if (!invokeFromClass(superclass, method, argCount)) {
                    return InterpretResult.RuntimeError;
                }
                frame = &this.frames[this.frameCount - 1];
                break;
            case OpCode.Closure:
                ObjFunction* fn = readConstant().obj.as!ObjFunction();
                ObjClosure* cl = ObjClosure.create(fn);
                this.push(Value(&cl.obj));
                for (int i = 0; i < cl.upvalueCount; i++) {
                    ubyte isLocal = readByte();
                    ubyte index = readByte();
                    if (isLocal == 1) {
                        cl.upvalues[i] = this.captureUpvalue(frame.slots + index);
                    } else {
                        cl.upvalues[i] = frame.closure.upvalues[index];
                    }
                }
                break;
            case OpCode.CloseUpvalue:
                this.closeUpvalues(this.stackTop - 1);
                this.pop();
                break;
            case OpCode.Return:
                Value result = this.pop();
                this.closeUpvalues(frame.slots);
                this.frameCount -= 1;
                if (this.frameCount == 0) {
                    this.pop();
                    return InterpretResult.Ok;
                }
                this.stackTop = frame.slots;
                this.push(result);
                frame = &this.frames[this.frameCount - 1];
                break;
            case OpCode.Class:
                this.push(Value(&ObjClass.create(readString()).obj));
                break;
            case OpCode.Inherit:
                Value superclass = this.peek(1);
                if (!superclass.isObjType(ObjType.Class)) {
                    this.runtimeError("Superclass must be a class.");
                    return InterpretResult.RuntimeError;
                }
                ObjClass* subclass = this.peek(0).obj.as!ObjClass();
                Table.addAll(
                    &superclass.obj.as!ObjClass().methods,
                    &subclass.methods
                );
                this.pop();
                break;
            case OpCode.Method:
                this.defineMethod(readString());
                break;
            default:
                stderr.writefln("ERROR: Unknown opcode '%d'", inst);
                break;
            }
        }
    }

    void push(Value val) {
        *this.stackTop = val;
        this.stackTop++;
    }

    Value pop() {
        this.stackTop--;
        return *this.stackTop;
    }

    private Value peek(int distance) {
        return this.stackTop[-1 - distance];
    }

    private bool callValue(Value callee, int argCount) {
        if (callee.isObj()) {
            Obj* callObj = callee.obj;
            ObjType t = callObj.objType;
            switch (callObj.objType) {
            case ObjType.BoundMethod:
                ObjBoundMethod* bm = callee.obj.as!ObjBoundMethod();
                this.instance.stackTop[-argCount - 1] = bm.receiver;
                return call(bm.method, argCount);
            case ObjType.Class:
                ObjClass* c = callObj.as!ObjClass();
                this.stackTop[-argCount - 1] = Value(&ObjInstance.create(c).obj);
                Value initializer;
                if (c.methods.get(VM.instance.initString, &initializer)) {
                    return call(initializer.obj.as!ObjClosure(), argCount);
                } else if (argCount != 0) {
                    this.runtimeError("Expected 0 arguments but got %d.", argCount);
                    return false;
                }
                return true;
            case ObjType.Closure:
                ObjClosure* callClObj = callObj.as!ObjClosure();
                return call(callClObj, argCount);
            case ObjType.Native:
                ObjNative* nativeObj = callObj.as!ObjNative();
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

    private bool invoke(ObjString* name, int argCount) {
        Value receiver = peek(argCount);
        if (!receiver.isObjType(ObjType.Instance)) {
            this.runtimeError("Only instances have methods.");
            return false;
        }
        ObjInstance* ins = receiver.obj.as!ObjInstance();

        Value val;
        if (ins.fields.get(name, &val)) {
            this.stackTop[-argCount - 1] = val;
            return this.callValue(val, argCount);
        }

        return this.invokeFromClass(ins.klass, name, argCount);
    }

    private bool invokeFromClass(ObjClass* klass, ObjString* name, int argCount) {
        Value method;
        if (!klass.methods.get(name, &method)) {
            this.runtimeError("Undefined property '%s'.", fromStringz(name.chars));
            return false;
        }
        return this.call(method.obj.as!ObjClosure(), argCount);
    }

    private bool bindMethod(ObjClass* klass, ObjString* name) {
        Value method;
        if (!klass.methods.get(name, &method)) {
            this.runtimeError("Undefined property '%s'.", fromStringz(name.chars));
            return false;
        }
        ObjBoundMethod* bm = ObjBoundMethod.create(this.peek(0), method.obj.as!ObjClosure());
        this.pop();
        this.push(Value(&bm.obj));
        return true;
    }

    private ObjUpvalue* captureUpvalue(Value* local) {
        ObjUpvalue* prev = null;
        ObjUpvalue* upv = this.openUpvalues;
        while (upv != null && upv.location > local) {
            prev = upv;
            upv = upv.next;
        }
        if (upv != null && upv.location == local) {
            return upv;
        }

        ObjUpvalue* createdUpvalue = ObjUpvalue.create(local);
        createdUpvalue.next = upv;
        if (prev == null) {
            this.openUpvalues = createdUpvalue;
        } else {
            prev.next = createdUpvalue;
        }
        return createdUpvalue;
    }

    private void closeUpvalues(Value* last) {
        while (this.openUpvalues != null && this.openUpvalues.location >= last) {
            ObjUpvalue* upv = this.openUpvalues;
            upv.closed = *upv.location;
            upv.location = &upv.closed;
            this.openUpvalues = upv.next;
        }
    }

    private bool call(ObjClosure* cl, int argCount) {
        if (argCount != cl.fn.arity) {
            this.runtimeError("Expected %d arguments but got %d.", cl.fn.arity, argCount);
            return false;
        }

        if (this.frameCount == FRAMES_MAX) {
            this.runtimeError("Stack overflow.");
            return false;
        }

        CallFrame* frame = &this.frames[this.frameCount++];
        frame.closure = cl;
        frame.ip = &cl.fn.c.code[0];
        frame.slots = this.stackTop - argCount - 1;
        return true;
    }

    void defineMethod(ObjString* name) {
        Value method = this.peek(0);
        ObjClass* k = peek(1).obj.as!ObjClass();
        k.methods.set(name, method);
        this.pop();
    }
}
