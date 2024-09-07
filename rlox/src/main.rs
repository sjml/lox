mod chunk;
mod debug;
mod value;
mod util;

use chunk::{Chunk, OpCode};

fn main() {
    let mut c = Chunk::new();
    let const_idx = c.add_constant(1.2);
    c.write(OpCode::Constant as u8, 123);
    c.write(const_idx as u8, 123);
    c.write(OpCode::Return as u8, 123);
    debug::disassemble_chunk(&c, "test chunk");

    c.free();
}
