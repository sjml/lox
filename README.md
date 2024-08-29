# plox (and friends?)

A Python implementation of Part II of [_Crafting Interpreters_](https://craftinginterpreters.com/).

There are many like it but this one is mine. 

Passes the test suite. You need Dart 2 (not Dart 3, alas) installed to run it though. 

There are other ways of Dart-ing but this works:

```
brew install dart-lang/dart/dart@2.19
```

I assume you already have Python installed. This will run all the tests indicating compliance with the AST-walker implementation from the book (jlox). The 13 is for chapter 13.

```
python test/run_tests.py 13
```

Might plug ahead with the bytecode-compiler version, but would also want to do in a different language than the book. Rust? Zig? Go? Haskell? TBD. 
