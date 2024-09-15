module lobj;

import std.stdio;
import std.string;
import std.conv;

import vm : VM;
import value : Value;
import chunk : Chunk;
import table : Table;
static import memory;

enum ObjType
{
    BoundMethod,
    Class,
    Instance,
    Closure,
    Function,
    Native,
    String,
    Upvalue,
}

struct Obj
{
    ObjType objType;
    bool isMarked;
    Obj* next = null;

    private static Obj* allocateObject(size_t size, ObjType objType)
    {
        Obj* ret = cast(Obj*) memory.reallocate(null, 0, size);
        ret.objType = objType;
        ret.isMarked = false;
        ret.next = VM.instance.objects;
        VM.instance.objects = ret;
        version (DebugLogGC)
        {
            writefln("%x allocate %u for %s", ret, size, to!string(ret.objType));
        }
        return ret;
    }

    void free()
    {
        version (DebugLogGC)
        {
            writef("%x free type %s", &this, to!string(this.objType));
            if (this.objType == ObjType.String)
            {
                ObjString* str = this.as!ObjString();
                size_t printLen = str.length;
                if (printLen > 10)
                {
                    printLen = 10;
                }
                writef(" (\"%s%s\")", fromStringz(str.chars[0 .. printLen]),
                        printLen == str.length ? "" : "...");
            }
            writeln("");
        }

        switch (this.objType)
        {
        case ObjType.BoundMethod:
            memory.free!ObjBoundMethod(&this);
            break;
        case ObjType.Class:
            this.as!ObjClass().methods.free();
            memory.free!ObjClass(&this);
            break;
        case ObjType.Instance:
            ObjInstance* oi = this.as!ObjInstance();
            oi.fields.free();
            memory.free!ObjInstance(oi);
            break;
        case ObjType.Closure:
            ObjClosure* oc = this.as!ObjClosure();
            memory.freeArray!(ObjUpvalue*)(oc.upvalues, oc.upvalueCount);
            memory.free!ObjClosure(oc);
            break;
        case ObjType.Function:
            ObjFunction* of = this.as!ObjFunction();
            of.c.free(); // "free"
            memory.free!ObjFunction(of);
            break;
        case ObjType.String:
            ObjString* os = this.as!ObjString();
            memory.freeArray!char(os.chars, os.length);
            memory.free!ObjString(os);
            break;
        case ObjType.Native:
            memory.free!(ObjNative)(&this);
            break;
        case ObjType.Upvalue:
            memory.free!(ObjUpvalue)(&this);
            break;
        default:
            assert(false); // unreachable
        }
    }

    void print()
    {
        switch (this.objType)
        {
        case ObjType.BoundMethod:
            this.as!ObjBoundMethod().method.fn.obj.print();
            break;
        case ObjType.Class:
            writef("%s", fromStringz(this.as!ObjClass().name.chars));
            break;
        case ObjType.Instance:
            writef("%s instance",
                    fromStringz(this.as!ObjInstance().klass.name.chars));
            break;
        case ObjType.Closure:
            this.as!ObjClosure().fn.obj.print();
            break;
        case ObjType.Function:
            ObjFunction* fn = this.as!ObjFunction();
            if (fn.name == null)
            {
                writef("<script>");
                return;
            }
            writef("<fn %s>", fromStringz(fn.name.chars));
            break;
        case ObjType.Native:
            writef("<native fn>");
            break;
        case ObjType.String:
            writef("%s", fromStringz(this.as!ObjString().chars));
            break;
        case ObjType.Upvalue:
            write("upvalue");
            break;
        default:
            assert(false); // unreachable
        }
    }

    pragma(inline) T* as(T)()
    {
        return cast(T*)&this;
    }
}

struct ObjClass
{
    Obj obj;
    ObjString* name;
    Table methods;

    static ObjClass* create(ObjString* name)
    {
        Obj* ret = Obj.allocateObject(ObjClass.sizeof, ObjType.Class);
        ObjClass* kRet = ret.as!ObjClass();
        kRet.name = name;
        return kRet;
    }
}

struct ObjInstance
{
    Obj obj;
    ObjClass* klass;
    Table fields;

    static ObjInstance* create(ObjClass* klass)
    {
        Obj* ret = Obj.allocateObject(ObjInstance.sizeof, ObjType.Instance);
        ObjInstance* iRet = ret.as!ObjInstance();
        iRet.klass = klass;
        return iRet;
    }
}

struct ObjBoundMethod
{
    Obj obj;
    Value receiver;
    ObjClosure* method;

    static ObjBoundMethod* create(Value receiver, ObjClosure* method)
    {
        Obj* ret = Obj.allocateObject(ObjBoundMethod.sizeof, ObjType.BoundMethod);
        ObjBoundMethod* bmRet = ret.as!ObjBoundMethod();
        bmRet.receiver = receiver;
        bmRet.method = method;
        return bmRet;
    }
}

struct ObjClosure
{
    Obj obj;
    ObjFunction* fn;
    ObjUpvalue** upvalues;
    size_t upvalueCount;

    static ObjClosure* create(ObjFunction* fn)
    {
        Obj* ret = Obj.allocateObject(ObjClosure.sizeof, ObjType.Closure);
        ObjClosure* clRet = ret.as!ObjClosure();
        clRet.fn = fn;
        clRet.upvalueCount = fn.upvalueCount;
        clRet.upvalues = cast(ObjUpvalue**) memory.reallocate(null, 0,
                (ObjUpvalue*).sizeof * fn.upvalueCount);
        memory.clear(clRet.upvalues, (ObjUpvalue*).sizeof * fn.upvalueCount);
        return clRet;
    }
}

struct ObjFunction
{
    Obj obj;
    size_t arity = 0;
    size_t upvalueCount = 0;
    Chunk c;
    ObjString* name = null;

    static ObjFunction* create()
    {
        Obj* ret = Obj.allocateObject(ObjFunction.sizeof, ObjType.Function);
        ObjFunction* fnRet = ret.as!ObjFunction();
        fnRet.arity = 0;
        fnRet.c = Chunk();
        fnRet.name = null;
        return fnRet;
    }
}

alias NativeFn = Value function(int argCount, Value* args);

struct ObjNative
{
    Obj obj;
    NativeFn fn;

    static ObjNative* create(NativeFn fn)
    {
        Obj* ret = Obj.allocateObject(ObjNative.sizeof, ObjType.Native);
        ObjNative* nvRet = ret.as!ObjNative();
        nvRet.fn = fn;
        return nvRet;
    }
}

struct ObjString
{
    Obj obj;
    size_t length;
    char* chars;
    uint hash;

    static ObjString* fromCopyOf(string input)
    {
        uint inHash = hashString(input);
        ObjString* interned = VM.instance.strings.findString(input, inHash);
        if (interned != null)
        {
            return interned;
        }
        ObjString* ret = ObjString.allocateString(input.length, inHash);

        foreach (idx, c; input)
        {
            ret.chars[idx] = c;
        }

        return ret;
    }

    static ObjString* allocateString(size_t length, uint hash)
    {
        Obj* ret = Obj.allocateObject(ObjString.sizeof, ObjType.String);
        ObjString* strRet = ret.as!ObjString();
        strRet.hash = hash;

        VM.instance.push(Value(&strRet.obj));
        VM.instance.strings.set(strRet, Value.nil());
        VM.instance.pop();
        strRet.chars = cast(char*) memory.reallocate(null, 0, length + 1);
        strRet.length = length;
        memory.clear(strRet.chars, length + 1);
        return strRet;
    }

    static uint hashString(string s)
    {
        return hashString(s.ptr, s.length);
    }

    static uint hashString(immutable(char)* c, size_t len)
    {
        uint h = 2_166_136_261;
        for (size_t i = 0; i < len; i++)
        {
            h ^= c[i];
            h *= 16_777_619;
        }
        return h;
    }
}

struct ObjUpvalue
{
    Obj obj;
    Value* location;
    Value closed;
    ObjUpvalue* next;

    static ObjUpvalue* create(Value* slot)
    {
        Obj* ret = Obj.allocateObject(ObjUpvalue.sizeof, ObjType.Upvalue);
        ObjUpvalue* upvRet = ret.as!ObjUpvalue();
        upvRet.closed = Value.nil();
        upvRet.location = slot;
        upvRet.next = null;
        return upvRet;
    }
}
