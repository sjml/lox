module chunk;

import std.conv;

import value : Value, ValueArray;
import memory : growCapacity;
import vm : VM;

enum OpCode
{
    Constant,
    Nil,
    True,
    False,
    Pop,
    GetLocal,
    SetLocal,
    GetGlobal,
    DefineGlobal,
    SetGlobal,
    GetUpvalue,
    SetUpvalue,
    Equal,
    Greater,
    Less,
    Add,
    Subtract,
    Multiply,
    Divide,
    Not,
    Negate,
    Print,
    Jump,
    JumpIfFalse,
    Loop,
    Call,
    Closure,
    CloseUpvalue,
    Return,
}

struct Chunk
{
    size_t count = 0;
    ubyte[] code;
    size_t[] lineNumbers;
    ValueArray constants;

    void write(ubyte data, size_t line)
    {
        if (this.code.length < this.count + 1)
        {
            this.code.length = growCapacity(this.code.length);
            this.lineNumbers.length = this.code.length;
        }
        this.code[this.count] = data;
        this.lineNumbers[this.count] = line;
        this.count += 1;
    }

    size_t addConstant(Value val)
    {
        VM.instance.push(val);
        this.constants.add(val);
        VM.instance.pop();
        return this.constants.count - 1;
    }

    void free()
    {
        this.code.length = 0;
        this.lineNumbers.length = 0;
        this.count = 0;
        this.constants.free();
    }
}
