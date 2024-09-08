use crate::value::Value;

#[cfg(any(feature = "debug_trace_execution", feature = "debug_print_code"))]
use crate::{Chunk, OpCode};

#[cfg(any(feature = "debug_trace_execution", feature = "debug_print_code"))]
pub fn disassemble_chunk(chunk: &Chunk, name: &str) {
    println!("== {} ==", name);
    let mut offset = 0;
    while offset < chunk.count {
        offset = disassemble_instruction(chunk, offset);
    }
}

#[cfg(any(feature = "debug_trace_execution", feature = "debug_print_code"))]
pub fn disassemble_instruction(chunk: &Chunk, offset: usize) -> usize {
    print!("{:04} ", offset);
    if offset > 0 && chunk.line_numbers[offset] == chunk.line_numbers[offset - 1] {
        print!("   | ");
    } else {
        print!("{:4} ", chunk.line_numbers[offset]);
    }

    let inst = chunk.code[offset];
    match OpCode::from_u8(inst) {
        Ok(op) => match op {
            OpCode::Constant => constant_instruction("OP_CONSTANT", chunk, offset),
            OpCode::Add => simple_instruction("OP_ADD", offset),
            OpCode::Subtract => simple_instruction("OP_SUBTRACT", offset),
            OpCode::Multiply => simple_instruction("OP_MULTIPLY", offset),
            OpCode::Divide => simple_instruction("OP_DIVIDE", offset),
            OpCode::Negate => simple_instruction("OP_NEGATE", offset),
            OpCode::Return => simple_instruction("OP_RETURN", offset),
        },
        Err(_) => {
            println!("Unknown opcode {}", inst);
            offset + 1
        }
    }
}

#[cfg(any(feature = "debug_trace_execution", feature = "debug_print_code"))]
fn simple_instruction(name: &str, offset: usize) -> usize {
    println!("{}", name);
    offset + 1
}

#[cfg(any(feature = "debug_trace_execution", feature = "debug_print_code"))]
fn constant_instruction(name: &str, chunk: &Chunk, offset: usize) -> usize {
    let constant_idx = chunk.code[offset + 1];
    print!("{:<16} {:4} '", name, constant_idx);
    print_value(chunk.constants.items[constant_idx as usize]);
    println!("'");
    offset + 2
}

pub fn print_value(val: Value) {
    print!("{}", val);
}
