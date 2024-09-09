module chunk;

import std.conv;

import value : Value, ValueArray;
import util : growCapacity;

enum OpCode {
    Constant,
    Add,
    Subtract,
    Multiply,
    Divide,
    Negate,
    Return,
}

struct Chunk {
    size_t count = 0;
    ubyte[] code;
    size_t[] line_numbers;
    ValueArray constants;

    void write(ubyte data, size_t line) {
        if (this.code.length < this.count + 1) {
            this.code.length = growCapacity(this.code.length);
            this.line_numbers.length = this.code.length;
        }
        this.code[this.count] = data;
        this.line_numbers[this.count] = line;
        this.count += 1;
    }

    ubyte addConstant(Value val) {
        this.constants.add(val);
        return to!byte(this.constants.count - 1);
    }

    void free() {
        this.code.length = 0;
        this.line_numbers.length = 0;
        this.count = 0;
        this.constants.free();
    }
}
