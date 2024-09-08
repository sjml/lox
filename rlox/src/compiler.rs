use crate::scanner::{Scanner, TokenType};

pub struct Compiler {}

impl Compiler {
    pub fn new() -> Self {
        Compiler {}
    }

    pub fn compile(&self, src: &str) {
        let mut scanner = Scanner::new(src);
        let mut line = 0;
        loop {
            let token = scanner.scan_token();
            if token.line != line {
                print!("{:4} ", token.line);
                line = token.line;
            } else {
                print!("   | ");
            }
            println!("{:?} '{}'", token.tok_type, token.lexeme);

            match token.tok_type {
                TokenType::EndOfFile => break,
                _ => continue,
            }
        }
    }
}
