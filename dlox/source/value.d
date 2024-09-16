module value;

import std.stdio;
import std.algorithm.comparison : equal;

import memory : growCapacity;
import lobj : Obj, ObjType, ObjString;

static const ulong SIGN_BIT = 0x8000000000000000;
static const ulong QNAN = 0x7ffc000000000000;
static const ulong TAG_NIL = 1;
static const ulong TAG_FALSE = 2;
static const ulong TAG_TRUE = 3;
static const ulong NIL_VAL = QNAN | TAG_NIL;
static const ulong FALSE_VAL = QNAN | TAG_FALSE;
static const ulong TRUE_VAL = QNAN | TAG_TRUE;
struct NValue {
    ulong data;

    this(double num) {
        this.data = *cast(ulong*) &num;
    }
    pragma(inline) @property double number() {
        return *cast(double*) &data;
    }
    pragma(inline) bool isNumber() {
        return (this.data & QNAN) != QNAN;
    }

    static NValue nil() {
        NValue v;
        v.data = QNAN | TAG_NIL;
        return v;
    }
    pragma(inline) bool isNil() {
        return this.data == NIL_VAL;
    }

    this(bool b) {
        this.data = b ? TRUE_VAL : FALSE_VAL;
    }
    pragma(inline) @property bool boolean() {
        return this.data == TRUE_VAL;
    }
    pragma(inline) bool isBoolean() {
        return (this.data | 1) == TRUE_VAL;
    }

    this(Obj* o) {
        this.data = (SIGN_BIT | QNAN | (*cast(ulong*) &o));
    }
    pragma(inline) @property Obj* obj() {
        return cast(Obj*) ((this.data) & ~(SIGN_BIT | QNAN));
    }
    pragma(inline) bool isObj() {
        return (((this.data) & (QNAN | SIGN_BIT)) == (QNAN | SIGN_BIT));
    }

    void print() {
        if (this.isBoolean()) {
            writef(this.boolean ? "true" : "false");
        }
        else if (this.isNil()) {
            write("nil");
        }
        else if (this.isNumber()) {
            writef("%g", this.number);
        }
        else if (this.isObj()) {
            this.obj.print();
        }
    }

    bool equals(NValue other) {
        if (this.isNumber() && other.isNumber()) {
            return this.number == other.number;
        }
        return this.data == other.data;
    }

    bool isFalsey() {
        if (this.isNil()) {
            return true;
        }
        if (this.isBoolean()) {
            return !this.boolean;
        }
        return false;
    }

    bool isObjType(ObjType ot) {
        return this.isObj() && this.obj.objType == ot;
    }
}

version (NaNBoxing) {
    alias Value = NValue;
}
else {
    enum ValueType {
        Boolean,
        Nil,
        Number,
        Obj,
    }

    struct Value {
        ValueType valType;
        union {
            bool boolean;
            double number;
            Obj* obj;
        }

        this(bool b) {
            this.valType = ValueType.Boolean;
            this.boolean = b;
        }

        this(double n) {
            this.valType = ValueType.Number;
            this.number = n;
        }

        this(Obj* o) {
            this.valType = ValueType.Obj;
            this.obj = o;
        }

        static Value nil() {
            Value v = Value();
            v.valType = ValueType.Nil;
            return v;
        }

        pragma(inline) bool isNumber() {
            return this.valType == ValueType.Number;
        }
        pragma(inline) bool isBoolean() {
            return this.valType == ValueType.Boolean;
        }
        pragma(inline) bool isObj() {
            return this.valType == ValueType.Obj;
        }
        pragma(inline) bool isNil() {
            return this.valType == ValueType.Nil;
        }

        void print() {
            switch (this.valType) {
            case ValueType.Boolean:
                writef(this.boolean ? "true" : "false");
                break;
            case ValueType.Nil:
                writef("nil");
                break;
            case ValueType.Number:
                writef("%g", this.number);
                break;
            case ValueType.Obj:
                this.obj.print();
                break;
            default:
                assert(false); // unreachable
            }
        }

        bool equals(Value other) {
            if (this.valType != other.valType) {
                return false;
            }
            switch (this.valType) {
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

        bool isFalsey() {
            if (this.isNil()) {
                return true;
            }
            if (this.isBoolean()) {
                return !this.boolean;
            }
            return false;
        }

        bool isObjType(ObjType ot) {
            return this.isObj() && this.obj.objType == ot;
        }
    }
}


struct ValueArray {
    size_t count;
    Value[] values;

    void add(Value val) {
        if (this.values.length < this.count + 1) {
            this.values.length = growCapacity(this.values.length);
        }
        this.values[this.count] = val;
        this.count += 1;
    }

    void free() {
        this.values.length = 0;
        this.count = 0;
    }
}
