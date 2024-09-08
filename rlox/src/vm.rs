use crate::chunk::{Chunk, OpCode};
use crate::compiler::Compiler;
use crate::debug;
use crate::value::Value;

const STACK_MAX: usize = 256;

pub enum InterpretResult {
    Success,
    CompileError,
    RuntimeError,
}

enum ArithmeticOperator {
    Add,
    Subtract,
    Multiply,
    Divide,
}

pub struct VM<'a> {
    chunk: Option<&'a Chunk>,
    ip_idx: usize,
    stack: [Value; STACK_MAX],
    stack_top_idx: usize,
}

impl<'a> VM<'a> {
    pub fn new() -> Self {
        Self {
            chunk: None,
            ip_idx: 0,
            stack: [0.0; STACK_MAX],
            stack_top_idx: 0,
        }
    }

    fn set_chunk(&mut self, new_chunk: &'a Chunk) {
        self.chunk = Some(new_chunk);
        self.ip_idx = 0;
    }

    pub fn reset_stack(&mut self) {
        self.stack_top_idx = 0;
    }

    pub fn free(&mut self) {}

    pub fn interpret(&mut self, src: &str) -> InterpretResult {
        let comp = Compiler::new();
        comp.compile(src);
        InterpretResult::Success
    }

    pub fn push(&mut self, val: Value) {
        self.stack[self.stack_top_idx] = val;
        self.stack_top_idx += 1;
    }

    pub fn pop(&mut self) -> Value {
        self.stack_top_idx -= 1;
        self.stack[self.stack_top_idx]
    }

    fn read_byte(&mut self) -> u8 {
        self.ip_idx += 1;
        self.chunk.expect("No chunk given to VM!").code[self.ip_idx - 1]
    }

    fn read_constant(&mut self) -> Value {
        let idx = self.read_byte();
        self.chunk.expect("No chunk given to VM!").constants.items[idx as usize]
    }

    fn binary_operation(&mut self, op: ArithmeticOperator) {
        let b = self.pop();
        let a = self.pop();
        let result = match op {
            ArithmeticOperator::Add => a + b,
            ArithmeticOperator::Subtract => a - b,
            ArithmeticOperator::Multiply => a * b,
            ArithmeticOperator::Divide => a / b,
        };
        self.push(result);
    }

    pub fn run(&mut self) -> InterpretResult {
        loop {
            #[cfg(feature = "debug_trace_execution")]
            {
                print!("          ");
                for slot_idx in 0..self.stack_top_idx {
                    print!("[ ");
                    debug::print_value(self.stack[slot_idx]);
                    print!(" ]");
                }
                println!();
                debug::disassemble_instruction(self.chunk, self.ip_idx);
            }
            let instruction = match OpCode::from_u8(self.read_byte()) {
                Ok(inst) => inst,
                Err(_) => return InterpretResult::CompileError,
            };
            match instruction {
                OpCode::Constant => {
                    let constant = self.read_constant();
                    self.push(constant);
                }
                OpCode::Add => self.binary_operation(ArithmeticOperator::Add),
                OpCode::Subtract => self.binary_operation(ArithmeticOperator::Subtract),
                OpCode::Multiply => self.binary_operation(ArithmeticOperator::Multiply),
                OpCode::Divide => self.binary_operation(ArithmeticOperator::Divide),
                OpCode::Negate => {
                    let val = self.pop();
                    self.push(-val);
                }
                OpCode::Return => {
                    debug::print_value(self.pop());
                    println!();
                    return InterpretResult::Success;
                }
            }
        }
    }
}
