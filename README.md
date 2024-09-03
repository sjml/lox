# {p|z}lox

I'm making my way through [_Crafting Interpreters_](https://craftinginterpreters.com/), using languages not in the book. This is helpful in a few ways! 

* Make sure I actually understand the concepts instead of just copying code, since I had to translate (from Java -> Python in Part II and from C -> Zig in Part III)
* In the case of Zig, actually build something useful in a language I've been meaning to learn
  * This might have been a mistake! As explaned below in the [zlox section](#zlox)


## plox

A [Python](https://www.python.org/) implementation of Part II.

There are many like it but this one is mine. 


## zlox

A [Zig](https://ziglang.org/) implementation of Part III. I am learning Zig as I write this, which means it is some **gnarly** Zig code. I intentionally don't use some useful things from Zig (like ArrayLists) because I want to implement myself. Alas, the result is kind of "writing C in Zig" and I spend a lot of time fighting the compiler. (And since Zig is a very young language, the compiler's error messages are not always helpful.)

Anyway, I am learning a lot both about bytecode machines AND Zig, so hey, mission accomplished? Or something?


## testing
`plox` at least passes the _Crafting Interpreters_ test suite. (`zlox` is still in progress.) You need Dart 2 (not Dart 3, alas) installed to run it though. 

There are other ways of Dart-ing but this works:

```
brew install dart-lang/dart/dart@2.19
```

I assume you already have Python installed. This will run all the tests indicating compliance with the AST-walker implementation from the book (jlox). The 13 is for chapter 13.

```
python test/run_tests.py 13
```
