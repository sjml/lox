#[derive(Debug, PartialEq, Clone, Copy)]
pub enum TokenType {
    // single-character
    LeftParen,
    RightParen,
    LeftBrace,
    RightBrace,
    Comma,
    Dot,
    Minus,
    Plus,
    Semicolon,
    Slash,
    Star,

    // one- or two-character
    Bang,
    BangEqual,
    Equal,
    EqualEqual,
    Greater,
    GreaterEqual,
    Less,
    LessEqual,

    // literals
    Identifier,
    String,
    Number,

    // keywords
    And,
    Class,
    Else,
    False,
    For,
    Fun,
    If,
    Nil,
    Or,
    Print,
    Return,
    Super,
    This,
    True,
    Var,
    While,

    Error,
    EndOfFile,
}

pub struct Token {
    pub tok_type: TokenType,
    pub line: u16,
    pub lexeme: String,
}

pub struct Scanner<'a> {
    src: &'a str,
    start_idx: usize,
    current_idx: usize,
    line: u16,
}

impl<'a> Scanner<'a> {
    pub fn new(src: &'a str) -> Self {
        Scanner {
            src,
            start_idx: 0,
            current_idx: 0,
            line: 1,
        }
    }

    pub fn set_source(&mut self, src: &'a str) {
        self.src = src;
        self.start_idx = 0;
        self.current_idx = 0;
        self.line = 1;
    }

    pub fn scan_token(&mut self) -> Token {
        self.skip_whitespace_and_comments();
        self.start_idx = self.current_idx;

        if self.is_at_end() {
            return self.make_token(TokenType::EndOfFile);
        }

        let c = self.advance();

        if c.is_ascii_alphabetic() || c == '_' {
            return self.identifier();
        }

        if c.is_ascii_digit() {
            return self.number();
        }

        match c {
            '(' => self.make_token(TokenType::LeftParen),
            ')' => self.make_token(TokenType::RightParen),
            '{' => self.make_token(TokenType::LeftBrace),
            '}' => self.make_token(TokenType::RightBrace),
            ';' => self.make_token(TokenType::Semicolon),
            ',' => self.make_token(TokenType::Comma),
            '.' => self.make_token(TokenType::Dot),
            '-' => self.make_token(TokenType::Minus),
            '+' => self.make_token(TokenType::Plus),
            '/' => self.make_token(TokenType::Slash),
            '*' => self.make_token(TokenType::Star),
            '!' => {
                let tok_type = if self.mmatch('=') {
                    TokenType::BangEqual
                } else {
                    TokenType::Bang
                };
                self.make_token(tok_type)
            }
            '=' => {
                let tok_type = if self.mmatch('=') {
                    TokenType::EqualEqual
                } else {
                    TokenType::Equal
                };
                self.make_token(tok_type)
            }
            '<' => {
                let tok_type = if self.mmatch('=') {
                    TokenType::LessEqual
                } else {
                    TokenType::Less
                };
                self.make_token(tok_type)
            }
            '>' => {
                let tok_type = if self.mmatch('=') {
                    TokenType::GreaterEqual
                } else {
                    TokenType::Greater
                };
                self.make_token(tok_type)
            }
            '"' => self.string(),
            _ => self.error_token("Unexpected character."),
        }
    }

    // TODO: this does not handle UTF-8 properly, but we rollin'
    fn advance(&mut self) -> char {
        self.current_idx += 1;
        return self.src.as_bytes()[self.current_idx - 1] as char;
    }

    fn is_at_end(&self) -> bool {
        self.current_idx >= self.src.len()
    }

    fn mmatch(&mut self, expected: char) -> bool {
        if self.is_at_end() {
            return false;
        }
        if self.src.as_bytes()[self.current_idx] as char != expected {
            return false;
        }
        self.current_idx += 1;
        true
    }

    fn make_token(&self, tok_type: TokenType) -> Token {
        Token {
            tok_type,
            line: self.line,
            lexeme: self.src[self.start_idx..self.current_idx].to_string(),
        }
    }

    fn error_token(&self, msg: &str) -> Token {
        Token {
            tok_type: TokenType::Error,
            line: self.line,
            lexeme: msg.to_string(),
        }
    }

    fn skip_whitespace_and_comments(&mut self) {
        loop {
            if self.is_at_end() {
                break;
            }
            let c = self.peek();
            match c {
                ' ' | '\r' | '\t' => {
                    self.advance();
                }
                '\n' => {
                    self.line += 1;
                    self.advance();
                }
                '/' => {
                    if self.peek_next() == '/' {
                        while self.peek() != '\n' && !self.is_at_end() {
                            self.advance();
                        }
                    } else {
                        return;
                    }
                }
                _ => break,
            }
        }
    }

    fn identifier(&mut self) -> Token {
        while self.peek().is_ascii_alphabetic()
            || self.peek() == '_'
            || self.peek().is_ascii_digit()
        {
            self.advance();
        }
        self.make_token(self.identifier_type())
    }

    fn identifier_type(&self) -> TokenType {
        let c = self.src.as_bytes()[self.start_idx] as char;
        match c {
            'a' => return self.check_keyword(1, "nd", TokenType::And),
            'c' => return self.check_keyword(1, "lass", TokenType::Class),
            'e' => return self.check_keyword(1, "lse", TokenType::Else),
            'f' => {
                if self.current_idx - self.start_idx > 1 {
                    let cn = self.src.as_bytes()[self.start_idx + 1] as char;
                    match cn {
                        'a' => return self.check_keyword(2, "lse", TokenType::False),
                        'o' => return self.check_keyword(2, "r", TokenType::For),
                        'u' => return self.check_keyword(2, "n", TokenType::Fun),
                        _ => {}
                    }
                }
            }
            'i' => return self.check_keyword(1, "f", TokenType::If),
            'n' => return self.check_keyword(1, "il", TokenType::Nil),
            'o' => return self.check_keyword(1, "r", TokenType::Or),
            'p' => return self.check_keyword(1, "rint", TokenType::Print),
            'r' => return self.check_keyword(1, "eturn", TokenType::Return),
            's' => return self.check_keyword(1, "uper", TokenType::Super),
            't' => {
                if self.current_idx - self.start_idx > 1 {
                    let cn = self.src.as_bytes()[self.start_idx + 1] as char;
                    match cn {
                        'h' => return self.check_keyword(2, "is", TokenType::This),
                        'r' => return self.check_keyword(2, "ue", TokenType::True),
                        _ => {}
                    }
                }
            }
            'v' => return self.check_keyword(1, "ar", TokenType::Var),
            'w' => return self.check_keyword(1, "hile", TokenType::While),
            _ => {}
        }

        TokenType::Identifier
    }

    fn check_keyword(&self, offset: usize, rest: &str, tok_type: TokenType) -> TokenType {
        if (self.current_idx - self.start_idx) != offset + rest.len() {
            return TokenType::Identifier;
        }
        if rest == &self.src[self.start_idx + offset..self.current_idx] {
            return tok_type;
        }
        TokenType::Identifier
    }

    fn number(&mut self) -> Token {
        while !self.is_at_end() && self.peek().is_ascii_digit() {
            self.advance();
        }

        if !self.is_at_end() && self.peek() == '.' && self.peek_next().is_ascii_digit() {
            self.advance();
            while !self.is_at_end() && self.peek().is_ascii_digit() {
                self.advance();
            }
        }
        self.make_token(TokenType::Number)
    }

    fn string(&mut self) -> Token {
        while self.peek() != '"' && !self.is_at_end() {
            if self.peek() == '\n' {
                self.line += 1;
            }
            self.advance();
        }

        if self.is_at_end() {
            return self.error_token("Unterminated string.");
        }

        self.advance();
        self.make_token(TokenType::String)
    }

    fn peek(&self) -> char {
        return self.src.as_bytes()[self.current_idx] as char;
    }

    fn peek_next(&self) -> char {
        if self.is_at_end() {
            return '\0';
        }
        return self.src.as_bytes()[self.current_idx + 1] as char;
    }
}
