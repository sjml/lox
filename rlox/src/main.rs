mod chunk;
mod debug;
mod value;
mod util;
mod vm;

use chunk::{Chunk, OpCode};
use vm::VM;

fn main() {

    let mut c = Chunk::new();
    let mut const_idx = c.add_constant(1.2);
    c.write(OpCode::Constant as u8, 123);
    c.write(const_idx as u8, 123);

    const_idx = c.add_constant(3.4);
    c.write(OpCode::Constant as u8, 123);
    c.write(const_idx as u8, 123);

    c.write(OpCode::Add as u8, 123);

    const_idx = c.add_constant(5.6);
    c.write(OpCode::Constant as u8, 123);
    c.write(const_idx as u8, 123);

    c.write(OpCode::Divide as u8, 123);

    c.write(OpCode::Negate as u8, 123);
    c.write(OpCode::Return as u8, 123);
    // debug::disassemble_chunk(&c, "test chunk");

    let mut vm = VM::new(&c);
    vm.interpret(&c);

    vm.free();
    c.free();
}
