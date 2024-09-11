module lobj;

import std.stdio;
import std.string;
import core.memory : GC;

import vm : VM;

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

    static ObjString* fromCopyOf(string input)
    {
        ObjString* ret = ObjString.allocateString(input.length);

        foreach (idx, c; input)
        {
            ret.chars[idx] = c;
        }

        return ret;
    }

    static ObjString* allocateString(size_t length)
    {
        Obj* ret = Obj.allocateObject(ObjString.sizeof, ObjType.String);
        ObjString* str_ret = ret.asString();
        str_ret.chars = cast(char*) GC.calloc(length + 1);
        str_ret.length = length;
        return str_ret;
    }

}
