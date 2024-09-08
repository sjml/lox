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
    Greater,
    Less,
}

pub struct VM {
    chunk: Option<Chunk>,
    ip_idx: usize,
    stack: [Value; STACK_MAX],
    stack_top_idx: usize,
}

impl VM {
    pub fn new() -> Self {
        Self {
            chunk: None,
            ip_idx: 0,
            stack: [Value::Nil; STACK_MAX],
            stack_top_idx: 0,
        }
    }

    fn set_chunk(&mut self, new_chunk: Chunk) {
        self.chunk = Some(new_chunk);
        self.ip_idx = 0;
    }

    pub fn reset_stack(&mut self) {
        self.stack_top_idx = 0;
    }

    fn runtime_error(&mut self, msg: &str) {
        eprintln!("{}", msg);
        let line = self.chunk.as_ref().expect("No chunk given!").line_numbers[self.ip_idx];
        eprintln!("[line {}] in script", line);
        self.reset_stack();
    }

    pub fn free(&mut self) {}

    pub fn interpret(&mut self, src: &str) -> InterpretResult {
        let mut c = Chunk::new();

        let mut comp = Compiler::new();
        if !comp.compile(src, &mut c) {
            return InterpretResult::CompileError;
        }
        self.set_chunk(c);

        self.run()
    }

    fn push(&mut self, val: Value) {
        self.stack[self.stack_top_idx] = val;
        self.stack_top_idx += 1;
    }

    fn pop(&mut self) -> Value {
        self.stack_top_idx -= 1;
        self.stack[self.stack_top_idx]
    }

    fn peek(&self, distance: usize) -> Value {
        self.stack[self.stack_top_idx - (1 + distance)]
    }

    fn read_byte(&mut self) -> u8 {
        self.ip_idx += 1;
        self.chunk.as_ref().expect("No chunk given to VM!").code[self.ip_idx - 1]
    }

    fn read_constant(&mut self) -> Value {
        let idx = self.read_byte();
        self.chunk
            .as_ref()
            .expect("No chunk given to VM!")
            .constants
            .items[idx as usize]
    }

    fn binary_operation(&mut self, op: ArithmeticOperator) -> bool {
        match (self.peek(1), self.peek(0)) {
            (Value::Number(a), Value::Number(b)) => {
                let _ = self.pop();
                let _ = self.pop();
                match op {
                    ArithmeticOperator::Add => self.push(Value::Number(a + b)),
                    ArithmeticOperator::Subtract => self.push(Value::Number(a - b)),
                    ArithmeticOperator::Multiply => self.push(Value::Number(a * b)),
                    ArithmeticOperator::Divide => self.push(Value::Number(a / b)),
                    ArithmeticOperator::Greater => self.push(Value::Boolean(a > b)),
                    ArithmeticOperator::Less => self.push(Value::Boolean(a < b)),
                };
                true
            }
            _ => {
                self.runtime_error("Operands must be numbers.");
                false
            }
        }
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
                debug::disassemble_instruction(&self.chunk.as_ref().unwrap(), self.ip_idx);
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
                OpCode::Nil => self.push(Value::Nil),
                OpCode::True => self.push(Value::Boolean(true)),
                OpCode::False => self.push(Value::Boolean(false)),
                OpCode::Equal => {
                    let b = self.pop();
                    let a = self.pop();
                    self.push(Value::Boolean(a.equals(&b)));
                }
                OpCode::Greater => {
                    if !self.binary_operation(ArithmeticOperator::Greater) {
                        return InterpretResult::RuntimeError;
                    }
                }
                OpCode::Less => {
                    if !self.binary_operation(ArithmeticOperator::Less) {
                        return InterpretResult::RuntimeError;
                    }
                }
                OpCode::Add => {
                    if !self.binary_operation(ArithmeticOperator::Add) {
                        return InterpretResult::RuntimeError;
                    }
                }
                OpCode::Subtract => {
                    if !self.binary_operation(ArithmeticOperator::Subtract) {
                        return InterpretResult::RuntimeError;
                    }
                }
                OpCode::Multiply => {
                    if !self.binary_operation(ArithmeticOperator::Multiply) {
                        return InterpretResult::RuntimeError;
                    }
                }
                OpCode::Divide => {
                    if !self.binary_operation(ArithmeticOperator::Divide) {
                        return InterpretResult::RuntimeError;
                    }
                }
                OpCode::Not => {
                    let v = self.pop();
                    self.push(Value::Boolean(v.is_falsey()));
                }
                OpCode::Negate => match self.peek(0) {
                    Value::Number(v) => {
                        let _ = self.pop();
                        self.push(Value::Number(-v));
                    }
                    _ => {
                        self.runtime_error("Operand must be an number.");
                        return InterpretResult::RuntimeError;
                    }
                },
                OpCode::Return => {
                    debug::print_value(self.pop());
                    println!();
                    return InterpretResult::Success;
                }
            }
        }
    }
}
