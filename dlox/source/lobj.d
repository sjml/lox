module lobj;

import std.stdio;
import std.string;
import core.memory : GC;

import vm : VM;
import value : Value;
import chunk : Chunk;

enum ObjType
{
    Function,
    Native,
    String,
}

struct Obj
{
    ObjType objType;
    Obj* next = null;

    private static Obj* allocateObject(size_t size, ObjType objType)
    {
        Obj* ret = cast(Obj*) GC.malloc(size);
        ret.objType = objType;
        ret.next = VM.instance.objects;
        VM.instance.objects = ret;
        return ret;
    }

    void free()
    {
        switch (this.objType)
        {
        case ObjType.Function:
            ObjFunction* of = this.asFunction();
            of.c.free();
            GC.free(&this);
            break;
        case ObjType.String:
            ObjString* os = this.asString();
            GC.free(os.chars);
            GC.free(&this);
            break;
        case ObjType.Native:
            GC.free(&this);
            break;
        default:
            assert(false); // unreachable
        }
    }

    void print()
    {
        switch (this.objType)
        {
        case ObjType.Function:
            ObjFunction* fn = this.asFunction();
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
            writef("%s", fromStringz(this.asString().chars));
            break;
        default:
            assert(false); // unreachable
        }
    }

    pragma(inline) ObjFunction* asFunction()
    {
        if (this.objType != ObjType.Function)
        {
            return null;
        }
        return cast(ObjFunction*)&this;
    }

    pragma(inline) ObjNative* asNative()
    {
        if (this.objType != ObjType.Native)
        {
            return null;
        }
        return cast(ObjNative*)&this;
    }

    pragma(inline) ObjString* asString()
    {
        if (this.objType != ObjType.String)
        {
            return null;
        }
        return cast(ObjString*)&this;
    }
}

struct ObjFunction
{
    Obj obj;
    size_t arity = 0;
    Chunk c;
    ObjString* name = null;

    static ObjFunction* create()
    {
        Obj* ret = Obj.allocateObject(ObjFunction.sizeof, ObjType.Function);
        ObjFunction* fnRet = ret.asFunction();
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
        ObjNative* nvRet = ret.asNative();
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
        ObjString* strRet = ret.asString();
        strRet.hash = hash;
        VM.instance.strings.set(strRet, Value.nil());
        strRet.chars = cast(char*) GC.calloc(length + 1);
        strRet.length = length;
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
