module value;

import std.stdio;
import std.algorithm.comparison : equal;

import util : growCapacity;
import lobj : Obj, ObjType, ObjString;

enum ValueType
{
    Boolean,
    Nil,
    Number,
    Obj,
}

struct Value
{
    ValueType val_type;
    union
    {
        bool boolean;
        double number;
        Obj* obj;
    }

    this(bool b)
    {
        this.val_type = ValueType.Boolean;
        this.boolean = b;
    }

    this(double n)
    {
        this.val_type = ValueType.Number;
        this.number = n;
    }

    this(Obj* o)
    {
        this.val_type = ValueType.Obj;
        this.obj = o;
    }

    static Value nil()
    {
        Value v = Value();
        v.val_type = ValueType.Nil;
        return v;
    }

    bool equals(Value other)
    {
        if (this.val_type != other.val_type)
        {
            return false;
        }
        switch (this.val_type)
        {
        case ValueType.Boolean:
            return this.boolean == other.boolean;
        case ValueType.Nil:
            return true;
        case ValueType.Number:
            return this.number == other.number;
        case ValueType.Obj:
            return this == other;
        default:
            assert(false); // unreachable
        }
    }

    bool isFalsey()
    {
        if (this.val_type == ValueType.Nil)
        {
            return true;
        }
        if (this.val_type == ValueType.Boolean)
        {
            return !this.boolean;
        }
        return false;
    }

    bool isObjType(ObjType ot)
    {
        return this.val_type == ValueType.Obj && this.obj.obj_type == ot;
    }
}

struct ValueArray
{
    size_t count;
    Value[] values;

    void add(Value val)
    {
        if (this.values.length < this.count + 1)
        {
            this.values.length = growCapacity(this.values.length);
        }
        this.values[this.count] = val;
        this.count += 1;
    }

    void free()
    {
        this.values.length = 0;
        this.count = 0;
    }
}

void printValue(Value val)
{
    switch (val.val_type)
    {
    case ValueType.Boolean:
        writef(val.boolean ? "true" : "false");
        break;
    case ValueType.Nil:
        writef("nil");
        break;
    case ValueType.Number:
        writef("%g", val.number);
        break;
    case ValueType.Obj:
        val.obj.print();
        break;
    default:
        assert(false); // unreachable
    }
}
