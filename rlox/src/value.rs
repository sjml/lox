use crate::util;

#[derive(Copy, Clone)]
pub enum Value {
    Boolean(bool),
    Number(f64),
    Nil,
}

impl Value {
    pub fn is_falsey(&self) -> bool {
        match self {
            Value::Nil => true,
            Value::Boolean(v) => *v,
            _ => false,
        }
    }

    pub fn equals(&self, other: &Value) -> bool {
        match (self, other) {
            (Value::Boolean(s), Value::Boolean(o)) => s == o,
            (Value::Number(s), Value::Number(o)) => s == o,
            (Value::Nil, Value::Nil) => true,
            _ => false,
        }
    }
}

pub struct ValueArray {
    capacity: usize,
    pub count: usize,
    pub items: Box<[Value]>,
}

// TODO: refactor this to be a Vec
impl ValueArray {
    pub fn new() -> Self {
        Self {
            capacity: 0,
            count: 0,
            items: Box::new([]),
        }
    }

    pub fn write(&mut self, val: Value) {
        if self.capacity < self.count + 1 {
            let old_cap = self.capacity;
            self.capacity = util::grow_capacity(old_cap);
            let mut new_data = vec![Value::Nil; self.capacity];
            new_data[..old_cap].clone_from_slice(&self.items);
            self.items = new_data.into_boxed_slice();
        }
        self.items[self.count] = val;
        self.count += 1;
    }

    // pub fn free(&mut self) {
    //     self.capacity = 0;
    //     self.count = 0;
    //     self.items = Box::new([]);
    // }
}
