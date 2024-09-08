use crate::util;
use crate::value::{Value, ValueArray};

#[repr(u8)]
#[derive(Debug, Copy, Clone)]
pub enum OpCode {
    Constant,
    Add,
    Subtract,
    Multiply,
    Divide,
    Negate,
    Return,
}

#[derive(Debug)]
pub enum OpCodeError {
    InvalidIntegerValue,
}

impl OpCode {
    const VARIANTS: [OpCode; 7] = [
        OpCode::Constant,
        OpCode::Add,
        OpCode::Subtract,
        OpCode::Multiply,
        OpCode::Divide,
        OpCode::Negate,
        OpCode::Return,
    ];

    pub fn from_u8(val: u8) -> Result<OpCode, OpCodeError> {
        Self::VARIANTS.get(val as usize).copied().ok_or(OpCodeError::InvalidIntegerValue)
    }
}

pub struct Chunk {
    capacity: usize,
    pub count: usize,
    pub code: Box<[u8]>,
    pub line_numbers: Box<[u16]>,
    pub constants: ValueArray,
}

// TODO: refactor this to use a Vec
impl Chunk {
    pub fn new() -> Self {
        Self {
            capacity: 0,
            count: 0,
            code: Box::new([]),
            line_numbers: Box::new([]),
            constants: ValueArray::new(),
        }
    }

    pub fn write(&mut self, byte: u8, line: u16) {
        if self.capacity < self.count + 1 {
            let old_cap = self.capacity;
            self.capacity = util::grow_capacity(old_cap);
            let mut new_data = vec![0u8; self.capacity];
            new_data[..old_cap].clone_from_slice(&self.code);
            self.code = new_data.into_boxed_slice();

            let mut new_line_numbers = vec![0u16; self.capacity];
            new_line_numbers[..old_cap].clone_from_slice(&self.line_numbers);
            self.line_numbers = new_line_numbers.into_boxed_slice();
        }
        self.code[self.count] = byte;
        self.line_numbers[self.count] = line;
        self.count += 1;
    }

    pub fn add_constant(&mut self, val: Value) -> usize {
        self.constants.write(val);
        self.constants.count - 1
    }

    pub fn free(&mut self) {
        self.capacity = 0;
        self.count = 0;
        self.code = Box::new([]);
        self.line_numbers = Box::new([]);
        self.constants.free();
    }
}
