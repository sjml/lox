module value;

import std.stdio;
import std.algorithm.comparison : equal;

import memory : growCapacity;
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
    ValueType valType;
    union
    {
        bool boolean;
        double number;
        Obj* obj;
    }

    this(bool b)
    {
        this.valType = ValueType.Boolean;
        this.boolean = b;
    }

    this(double n)
    {
        this.valType = ValueType.Number;
        this.number = n;
    }

    this(Obj* o)
    {
        this.valType = ValueType.Obj;
        this.obj = o;
    }

    static Value nil()
    {
        Value v = Value();
        v.valType = ValueType.Nil;
        return v;
    }

    bool equals(Value other)
    {
        if (this.valType != other.valType)
        {
            return false;
        }
        switch (this.valType)
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
        if (this.valType == ValueType.Nil)
        {
            return true;
        }
        if (this.valType == ValueType.Boolean)
        {
            return !this.boolean;
        }
        return false;
    }

    bool isObjType(ObjType ot)
    {
        return this.valType == ValueType.Obj && this.obj.objType == ot;
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
    switch (val.valType)
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
