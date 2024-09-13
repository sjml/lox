module lox_debug;

import std.stdio;

import value : printValue;
import chunk : Chunk, OpCode;

void disassembleChunk(Chunk* chunk, string name)
{
    writefln("== %s ==", name);

    for (size_t idx = 0; idx < chunk.count;)
    {
        idx = disassembleInstruction(chunk, idx);
    }
}

size_t disassembleInstruction(Chunk* chunk, size_t offset)
{
    writef("%04d ", offset);
    if (offset > 0 && chunk.lineNumbers[offset] == chunk.lineNumbers[offset - 1])
    {
        writef("   | ");
    }
    else
    {
        writef("%4d ", chunk.lineNumbers[offset]);
    }

    ubyte inst = chunk.code[offset];
    switch (inst)
    {
    case OpCode.Constant:
        return constantInstruction("OP_CONSTANT", chunk, offset);
    case OpCode.Nil:
        return simpleInstruction("OP_NIL", offset);
    case OpCode.True:
        return simpleInstruction("OP_TRUE", offset);
    case OpCode.False:
        return simpleInstruction("OP_FALSE", offset);
    case OpCode.Pop:
        return simpleInstruction("OP_POP", offset);
    case OpCode.GetGlobal:
        return constantInstruction("OP_GET_GLOBAL", chunk, offset);
    case OpCode.DefineGlobal:
        return constantInstruction("OP_DEFINE_GLOBAL", chunk, offset);
    case OpCode.SetGlobal:
        return constantInstruction("OP_SET_GLOBAL", chunk, offset);
    case OpCode.Equal:
        return simpleInstruction("OP_EQUAL", offset);
    case OpCode.Greater:
        return simpleInstruction("OP_GREATER", offset);
    case OpCode.Less:
        return simpleInstruction("OP_LESS", offset);
    case OpCode.Add:
        return simpleInstruction("OP_ADD", offset);
    case OpCode.Subtract:
        return simpleInstruction("OP_SUBTRACT", offset);
    case OpCode.Multiply:
        return simpleInstruction("OP_MULTIPLY", offset);
    case OpCode.Divide:
        return simpleInstruction("OP_DIVIDE", offset);
    case OpCode.Not:
        return simpleInstruction("OP_NOT", offset);
    case OpCode.Negate:
        return simpleInstruction("OP_NEGATE", offset);
    case OpCode.Print:
        return simpleInstruction("OP_PRINT", offset);
    case OpCode.Return:
        return simpleInstruction("OP_RETURN", offset);
    default:
        writefln("Unknown opcode %d", inst);
        return offset + 1;
    }
}

size_t simpleInstruction(string name, size_t offset)
{
    writefln("%s", name);
    return offset + 1;
}

size_t constantInstruction(string name, Chunk* chunk, size_t offset)
{
    ubyte constantIdx = chunk.code[offset + 1];
    writef("%-16s %4d '", name, constantIdx);
    printValue(chunk.constants.values[constantIdx]);
    writefln("'");
    return offset + 2;
}
