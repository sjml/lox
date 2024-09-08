mod chunk;
mod compiler;
mod debug;
mod scanner;
mod util;
mod value;
mod vm;

use std::fs;
use std::io;
use std::io::Write;

use vm::{InterpretResult, VM};

fn main() {
    let mut vm = VM::new();

    let args: Vec<String> = std::env::args().collect();
    match args.len() {
        1 => repl(&mut vm),
        2 => run_file(&mut vm, args.get(1).unwrap()),
        _ => {
            eprintln!("Usage: rlox [path]");
            std::process::exit(64);
        }
    }

    vm.free();
}

fn repl(vm: &mut VM) {
    let stdin = io::stdin();
    let mut stdout = io::stdout();
    let input = &mut String::new();

    loop {
        let _ = stdout.write(b"> ");
        let _ = stdout.flush();
        input.clear();
        match stdin.read_line(input) {
            Ok(_) => {}
            Err(e) => {
                eprintln!("ERROR: {:}", e);
            }
        };
        if input.is_empty() {
            // got a Ctrl-D
            println!("\nExiting...");
            break;
        }

        vm.interpret(input.trim_end());
    }
}

fn run_file(vm: &mut VM, fpath: &str) {
    let src = match fs::read_to_string(fpath) {
        Ok(s) => s,
        Err(err) => {
            eprintln!("ERROR: Could not read file {}:\n{:}", fpath, err);
            std::process::exit(74);
        }
    };
    match vm.interpret(&src) {
        InterpretResult::CompileError => std::process::exit(65),
        InterpretResult::RuntimeError => std::process::exit(70),
        InterpretResult::Success => {}
    }
}
