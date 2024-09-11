module lobj;

import std.stdio;
import std.string;
import core.memory : GC;

import vm : VM;
import value : Value;

enum ObjType
{
    String,
}

struct Obj
{
    ObjType obj_type;
    Obj* next = null;

    private static Obj* allocateObject(size_t size, ObjType obj_type)
    {
        Obj* ret = cast(Obj*) GC.malloc(size);
        ret.obj_type = obj_type;
        ret.next = VM.instance.objects;
        VM.instance.objects = ret;
        return ret;
    }

    void free()
    {
        switch (this.obj_type)
        {
        case ObjType.String:
            ObjString* os = this.asString();
            GC.free(os.chars);
            GC.free(&this);
            break;
        default:
            assert(false); // unreachable
        }
    }

    void print()
    {
        switch (this.obj_type)
        {
        case ObjType.String:
            writef("%s", fromStringz(this.asString().chars));
            break;
        default:
            assert(false); // unreachable
        }
    }

    pragma(inline) ObjString* asString()
    {
        if (this.obj_type != ObjType.String)
        {
            return null;
        }
        return cast(ObjString*)&this;
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
        ObjString* str_ret = ret.asString();
        str_ret.hash = hash;
        VM.instance.strings.set(str_ret, Value.nil());
        str_ret.chars = cast(char*) GC.calloc(length + 1);
        str_ret.length = length;
        return str_ret;
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
