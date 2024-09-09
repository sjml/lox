module value;

import std.stdio;

import util : growCapacity;

alias Value = double;

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

void printValue(Value val) {
    writef("%g", val);
}


