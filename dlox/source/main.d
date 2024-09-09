import std.conv;

import chunk : Chunk, OpCode;
import lox_debug;

int main()
{
    Chunk chunk;

    size_t constant_idx = chunk.addConstant(1.2);
    chunk.write(OpCode.Constant, 123);
    chunk.write(to!byte(constant_idx), 123);
    chunk.write(OpCode.Return, 123);

    lox_debug.disassembleChunk(&chunk, "test chunk");

    chunk.free();
    return 0;
}
