use crate::scanner::TokenType;

#[derive(Copy, Clone)]
pub enum Precedence {
    None,
    Assignment,
    Or,
    And,
    Equality,
    Comparison,
    Term,
    Factor,
    Unary,
    Call,
    Primary,
}

impl Precedence {
    pub fn get_next(&self) -> Precedence {
        match self {
            Precedence::None => Precedence::Assignment,
            Precedence::Assignment => Precedence::Or,
            Precedence::Or => Precedence::And,
            Precedence::And => Precedence::Equality,
            Precedence::Equality => Precedence::Comparison,
            Precedence::Comparison => Precedence::Term,
            Precedence::Term => Precedence::Factor,
            Precedence::Factor => Precedence::Unary,
            Precedence::Unary => Precedence::Call,
            Precedence::Call => Precedence::Primary,
            Precedence::Primary => Precedence::Primary,
        }
    }
}

pub enum ParseFunction {
    None,
    Unary,
    Grouping,
    Number,
    Binary,
    Literal,
    // String,
    // Variable,
    // And,
    // Or,
}

pub struct ParseRule {
    pub prefix: ParseFunction,
    pub infix: ParseFunction,
    pub precedence: Precedence,
}

pub fn get_rule(op: TokenType) -> ParseRule {
    match op {
        TokenType::LeftParen => ParseRule {
            prefix: ParseFunction::Grouping,
            infix: ParseFunction::None,
            precedence: Precedence::None,
        },
        TokenType::RightParen => ParseRule {
            prefix: ParseFunction::None,
            infix: ParseFunction::None,
            precedence: Precedence::None,
        },
        TokenType::LeftBrace => ParseRule {
            prefix: ParseFunction::None,
            infix: ParseFunction::None,
            precedence: Precedence::None,
        },
        TokenType::RightBrace => ParseRule {
            prefix: ParseFunction::None,
            infix: ParseFunction::None,
            precedence: Precedence::None,
        },
        TokenType::Comma => ParseRule {
            prefix: ParseFunction::None,
            infix: ParseFunction::None,
            precedence: Precedence::None,
        },
        TokenType::Dot => ParseRule {
            prefix: ParseFunction::None,
            infix: ParseFunction::None,
            precedence: Precedence::None,
        },
        TokenType::Minus => ParseRule {
            prefix: ParseFunction::Unary,
            infix: ParseFunction::Binary,
            precedence: Precedence::Term,
        },
        TokenType::Plus => ParseRule {
            prefix: ParseFunction::None,
            infix: ParseFunction::Binary,
            precedence: Precedence::Term,
        },
        TokenType::Semicolon => ParseRule {
            prefix: ParseFunction::None,
            infix: ParseFunction::None,
            precedence: Precedence::None,
        },
        TokenType::Slash => ParseRule {
            prefix: ParseFunction::None,
            infix: ParseFunction::Binary,
            precedence: Precedence::Factor,
        },
        TokenType::Star => ParseRule {
            prefix: ParseFunction::None,
            infix: ParseFunction::Binary,
            precedence: Precedence::Factor,
        },
        TokenType::Bang => ParseRule {
            prefix: ParseFunction::Unary,
            infix: ParseFunction::None,
            precedence: Precedence::None,
        },
        TokenType::BangEqual => ParseRule {
            prefix: ParseFunction::None,
            infix: ParseFunction::Binary,
            precedence: Precedence::Equality,
        },
        TokenType::Equal => ParseRule {
            prefix: ParseFunction::None,
            infix: ParseFunction::None,
            precedence: Precedence::None,
        },
        TokenType::EqualEqual => ParseRule {
            prefix: ParseFunction::None,
            infix: ParseFunction::Binary,
            precedence: Precedence::Equality,
        },
        TokenType::Greater => ParseRule {
            prefix: ParseFunction::None,
            infix: ParseFunction::Binary,
            precedence: Precedence::Comparison,
        },
        TokenType::GreaterEqual => ParseRule {
            prefix: ParseFunction::None,
            infix: ParseFunction::Binary,
            precedence: Precedence::Comparison,
        },
        TokenType::Less => ParseRule {
            prefix: ParseFunction::None,
            infix: ParseFunction::Binary,
            precedence: Precedence::Comparison,
        },
        TokenType::LessEqual => ParseRule {
            prefix: ParseFunction::None,
            infix: ParseFunction::Binary,
            precedence: Precedence::Comparison,
        },
        TokenType::Identifier => ParseRule {
            prefix: ParseFunction::None,
            infix: ParseFunction::None,
            precedence: Precedence::None,
        },
        TokenType::String => ParseRule {
            prefix: ParseFunction::None,
            infix: ParseFunction::None,
            precedence: Precedence::None,
        },
        TokenType::Number => ParseRule {
            prefix: ParseFunction::Number,
            infix: ParseFunction::None,
            precedence: Precedence::None,
        },
        TokenType::And => ParseRule {
            prefix: ParseFunction::None,
            infix: ParseFunction::None,
            precedence: Precedence::None,
        },
        TokenType::Class => ParseRule {
            prefix: ParseFunction::None,
            infix: ParseFunction::None,
            precedence: Precedence::None,
        },
        TokenType::Else => ParseRule {
            prefix: ParseFunction::None,
            infix: ParseFunction::None,
            precedence: Precedence::None,
        },
        TokenType::False => ParseRule {
            prefix: ParseFunction::Literal,
            infix: ParseFunction::None,
            precedence: Precedence::None,
        },
        TokenType::For => ParseRule {
            prefix: ParseFunction::None,
            infix: ParseFunction::None,
            precedence: Precedence::None,
        },
        TokenType::Fun => ParseRule {
            prefix: ParseFunction::None,
            infix: ParseFunction::None,
            precedence: Precedence::None,
        },
        TokenType::If => ParseRule {
            prefix: ParseFunction::None,
            infix: ParseFunction::None,
            precedence: Precedence::None,
        },
        TokenType::Nil => ParseRule {
            prefix: ParseFunction::Literal,
            infix: ParseFunction::None,
            precedence: Precedence::None,
        },
        TokenType::Or => ParseRule {
            prefix: ParseFunction::None,
            infix: ParseFunction::None,
            precedence: Precedence::None,
        },
        TokenType::Print => ParseRule {
            prefix: ParseFunction::None,
            infix: ParseFunction::None,
            precedence: Precedence::None,
        },
        TokenType::Return => ParseRule {
            prefix: ParseFunction::None,
            infix: ParseFunction::None,
            precedence: Precedence::None,
        },
        TokenType::Super => ParseRule {
            prefix: ParseFunction::None,
            infix: ParseFunction::None,
            precedence: Precedence::None,
        },
        TokenType::This => ParseRule {
            prefix: ParseFunction::None,
            infix: ParseFunction::None,
            precedence: Precedence::None,
        },
        TokenType::True => ParseRule {
            prefix: ParseFunction::Literal,
            infix: ParseFunction::None,
            precedence: Precedence::None,
        },
        TokenType::Var => ParseRule {
            prefix: ParseFunction::None,
            infix: ParseFunction::None,
            precedence: Precedence::None,
        },
        TokenType::While => ParseRule {
            prefix: ParseFunction::None,
            infix: ParseFunction::None,
            precedence: Precedence::None,
        },
        TokenType::Error => ParseRule {
            prefix: ParseFunction::None,
            infix: ParseFunction::None,
            precedence: Precedence::None,
        },
        TokenType::EndOfFile => ParseRule {
            prefix: ParseFunction::None,
            infix: ParseFunction::None,
            precedence: Precedence::None,
        },
    }
}
