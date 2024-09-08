use std::collections::VecDeque;

#[cfg(feature = "debug_print_code")]
use crate::debug;

use crate::chunk::{Chunk, OpCode};
use crate::precedence::{get_rule, ParseFunction, Precedence};
use crate::scanner::{Scanner, Token, TokenType};
use crate::value::Value;

struct Parser {
    token_stream: VecDeque<Token>,
    had_error: bool,
    panic_mode: bool,
}

impl Parser {
    fn push_tok(&mut self, tok: Token) {
        self.token_stream.push_back(tok);
        while self.token_stream.len() > 2 {
            self.token_stream.pop_front();
        }
    }

    fn get_current(&self) -> &Token {
        let idx = if self.token_stream.len() == 1 { 0 } else { 1 };
        &self.token_stream[idx]
    }

    fn get_previous(&self) -> &Token {
        &self.token_stream[0]
    }
}

pub struct Compiler<'a> {
    parser: Parser,
    scanner: Scanner<'a>,
    compiling_chunk: Option<&'a mut Chunk>,
}

impl<'a> Compiler<'a> {
    pub fn new() -> Self {
        Compiler {
            parser: Parser {
                token_stream: VecDeque::new(),
                had_error: false,
                panic_mode: false,
            },
            scanner: Scanner::new(""),
            compiling_chunk: None,
        }
    }

    pub fn compile(&'a mut self, src: &'a str, chunk: &'a mut Chunk) -> bool {
        self.scanner.set_source(src);
        self.compiling_chunk = Some(chunk);
        self.advance();
        self.expression();
        self.consume(TokenType::EndOfFile, "Expect end of expression.");
        self.end_compiler();
        !self.parser.had_error
    }

    fn advance(&mut self) {
        self.parser.push_tok(self.scanner.scan_token());
        if self.parser.get_current().tok_type == TokenType::Error {
            let msg = self.parser.get_current().lexeme.clone();
            self.error(&msg, true);
            self.advance();
        }
    }

    fn consume(&mut self, tok_type: TokenType, msg: &str) {
        if self.parser.get_current().tok_type == tok_type {
            self.advance();
            return;
        }
        self.error(msg, true);
    }

    fn emit_byte(&mut self, byte: u8) {
        let c = self
            .compiling_chunk
            .as_mut()
            .expect("No compiling chunk given!");
        c.write(byte, self.parser.get_previous().line);
    }

    fn emit_bytes(&mut self, byte1: u8, byte2: u8) {
        self.emit_byte(byte1);
        self.emit_byte(byte2);
    }

    fn end_compiler(&mut self) {
        self.emit_return();
        #[cfg(feature = "debug_print_code")]
        if !self.parser.had_error {
            debug::disassemble_chunk(self.compiling_chunk, "code");
        }
    }

    fn emit_return(&mut self) {
        self.emit_byte(OpCode::Return as u8);
    }

    fn emit_constant(&mut self, val: Value) {
        let const_idx = self.make_constant(val);
        self.emit_bytes(OpCode::Constant as u8, const_idx);
    }

    fn make_constant(&mut self, val: Value) -> u8 {
        let c = self
            .compiling_chunk
            .as_mut()
            .expect("No compiling chunk given!");
        let const_idx = c.add_constant(val);
        if const_idx > u8::MAX as usize {
            self.error("Too many constants in one chunk.", false);
            return 0;
        }
        const_idx as u8
    }

    fn expression(&mut self) {
        self.parse_precedence(Precedence::Assignment);
    }

    fn grouping(&mut self) {
        self.expression();
        self.consume(TokenType::RightParen, "Expect ')' after expression.");
    }

    fn number(&mut self) {
        // lexeme has already been checked to be valid float
        let val: f64 = self.parser.get_previous().lexeme.parse().unwrap();
        self.emit_constant(Value::Number(val));
    }

    fn unary(&mut self) {
        let op = self.parser.get_previous().tok_type;
        self.parse_precedence(Precedence::Unary);
        match op {
            TokenType::Bang => self.emit_byte(OpCode::Not as u8),
            TokenType::Minus => self.emit_byte(OpCode::Negate as u8),
            _ => unreachable!(),
        }
    }

    fn binary(&mut self) {
        let op = self.parser.get_previous().tok_type;
        let rule = get_rule(op);
        self.parse_precedence(rule.precedence.get_next());

        match op {
            TokenType::BangEqual => self.emit_bytes(OpCode::Equal as u8, OpCode::Not as u8),
            TokenType::EqualEqual => self.emit_byte(OpCode::Equal as u8),
            TokenType::Greater => self.emit_byte(OpCode::Greater as u8),
            TokenType::GreaterEqual => self.emit_bytes(OpCode::Less as u8, OpCode::Not as u8),
            TokenType::Less => self.emit_byte(OpCode::Less as u8),
            TokenType::LessEqual => self.emit_bytes(OpCode::Greater as u8, OpCode::Not as u8),
            TokenType::Plus => self.emit_byte(OpCode::Add as u8),
            TokenType::Minus => self.emit_byte(OpCode::Subtract as u8),
            TokenType::Star => self.emit_byte(OpCode::Multiply as u8),
            TokenType::Slash => self.emit_byte(OpCode::Divide as u8),
            _ => unreachable!(),
        }
    }

    fn literal(&mut self) {
        match self.parser.get_previous().tok_type {
            TokenType::False => self.emit_byte(OpCode::False as u8),
            TokenType::Nil => self.emit_byte(OpCode::Nil as u8),
            TokenType::True => self.emit_byte(OpCode::True as u8),
            _ => unreachable!(),
        }
    }

    fn parse_precedence(&mut self, precedence: Precedence) {
        self.advance();
        let prefix_pfn = get_rule(self.parser.get_previous().tok_type).prefix;
        self.call_parse_function(prefix_pfn);

        while precedence as u8 <= get_rule(self.parser.get_current().tok_type).precedence as u8 {
            self.advance();
            let infix_pfn = get_rule(self.parser.get_previous().tok_type).infix;
            self.call_parse_function(infix_pfn);
        }
    }

    fn call_parse_function(&mut self, pfn: ParseFunction) {
        match pfn {
            ParseFunction::None => self.error("Expect expression.", false),
            ParseFunction::Unary => self.unary(),
            ParseFunction::Grouping => self.grouping(),
            ParseFunction::Number => self.number(),
            ParseFunction::Binary => self.binary(),
            ParseFunction::Literal => self.literal(),
            // ParseFunction::String => todo!(),
            // ParseFunction::Variable => todo!(),
            // ParseFunction::And => todo!(),
            // ParseFunction::Or => todo!(),
        }
    }

    fn error(&mut self, message: &str, at_current: bool) {
        if self.parser.panic_mode {
            return;
        }
        self.parser.panic_mode = true;

        let token = if at_current {
            self.parser.get_current()
        } else {
            self.parser.get_previous()
        };

        eprint!("[line {}] Error", token.line);
        match token.tok_type {
            TokenType::EndOfFile => {
                eprint!(" at end");
            }
            TokenType::Error => {}
            _ => {
                eprint!(" at '{}'", token.lexeme);
            }
        }
        eprintln!(": {}", message);

        self.parser.had_error = true;
    }
}
