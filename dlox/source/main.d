import vm : VM;
import chunk : Chunk, OpCode;
import lox_debug;

int main()
{
    Chunk chunk;
    VM.setup();

    ubyte constant_idx = chunk.addConstant(1.2);
    chunk.write(OpCode.Constant, 123);
    chunk.write(constant_idx, 123);

    constant_idx = chunk.addConstant(3.4);
    chunk.write(OpCode.Constant, 123);
    chunk.write(constant_idx, 123);

    chunk.write(OpCode.Add, 123);

    constant_idx = chunk.addConstant(5.6);
    chunk.write(OpCode.Constant, 123);
    chunk.write(constant_idx, 123);

    chunk.write(OpCode.Divide, 123);

    chunk.write(OpCode.Negate, 123);
    chunk.write(OpCode.Return, 123);

    VM.interpret(&chunk);

    VM.teardown();
    chunk.free();
    return 0;
}
