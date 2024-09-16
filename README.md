# {p|~~&nbsp;z | r |~~ d}lox

I made my way through [_Crafting Interpreters_](https://craftinginterpreters.com/), using languages not in the book. This was helpful in a few ways! 

* Made sure I actually understood the concepts instead of just copying code, since I had to translate (from Java -> Python in Part II and from C -> Zig/Rust/D in Part III)
* In the case of Zig, actually build something useful in a language I've been meaning to learn
  * This might have been a mistake! As explaned below in the [zlox section](#zlox)
* In the case of Rust, get more practice in a useful language! 
* In the case of D, actually finish the project!

## testing
`plox` and `dlox`, both pass the _Crafting Interpreters_ test suite. You need Dart 2 (not Dart 3, alas) installed to run it though. 

There are other ways of getting the pre-reqs, but this works:
```
brew install dart-lang/dart/dart@2.19 python ldc dub
```

Then to see the test suite go nuts: 
```
python test/run_tests.py
```

If you want to see the benchmark time for the Python version (it's slow, like literally over 100× slower):
```
python test/run_tests.py bench_plox
```

On my M1 MacBook Pro:
```
%> python ./test/run_tests.py
Updating book repo...
Installing testing dependencies...
Running jlox test suite with Python AST-walk interpreter...
All 239 tests passed (556 expectations).
Running clox test suite with D-lang bytecode interpreter...
All 246 tests passed (568 expectations).
Running clox test suite with canonical clox interpreter...
All 246 tests passed (568 expectations).

 plox test suite execution time: 8.77459
 clox test suite execution time: 2.93690
cclox test suite execution time: 2.37257


Running zoo benchmark...
 plox benchmark time: 274.2626838684082
 clox benchmark time: 2.66735
cclox benchmark time: 2.50378
```

## plox

A [Python](https://www.python.org/) implementation of Part II.

There are many like it but this one is mine. 

(Made and tested with Python 3.12.5.)


## dlox

A [D](https://dlang.org/) implementation of Part III. This is my first code in D that is anything beyond the most trivial "Hello world" kinda stuff. My (possibly wrong) perception is that D doesn't seem to have a ton of traction these days — too close to C to replace it, not memory-safe enough to compete with Rust... at the same time, it's super familiar to all kinds of programmers so maybe its easier entry is a feature. 

In any case, its similarity to C works to my advantage here — it lets me do low-level memory manipulation like C, but the semantics are _juuuuuust_ different enough that I have to think as I write code instead of just mindlessly copying. So hey, there we go. 

(Made and tested with LDC 1.39.0)

(For a while this was actually running *faster* than the canonical C version from the book... until the optimizations chapter at the end. C'est la vie. Still very close on the zoo benchmark, though, only about 5% slower in my tests.)


## rlox

A [Rust](https://www.rust-lang.org/) implementation of Part III. I initially tried with Zig (see [zlox](#zlox)) but eventually came back to Rust, which I know a know a bit better from re-implementing [my paper-writing tool in it](https://github.com/sjml/paper). 

(Made and tested with Rust 1.81.0.)

Abandoned this one as I approached the same area I was forced to abandon the Zig implementation. I was getting to the point where the book was doing very C-things (struct polymorphism, downcasting with pointer arithmetic). In researching the best way to accomplish these things in Rust I found other people who had built Lox interpreters in Rust and they faced a choice of either (a) bad performance, very close to the Java AST version or (b) using lots of `unsafe` calls. I didn't like either of those choices! So I bailed, again. 


## zlox

An abandoned [Zig](https://ziglang.org/) implementation of Part III. I was learning Zig as I wrote this, which means it is some **gnarly** Zig code. I intentionally didn't use some useful things from Zig (like ArrayLists) because I wanted to implement myself. Alas, the result is kind of "writing C in Zig" and I spent a lot of time fighting the compiler. (And since Zig is a very young language, the compiler's error messages are not always helpful.)

Anyway, I learned a lot both about bytecode machines AND Zig, so hey, mission accomplished? Or something?

(Made and tested with Zig 0.13.0.)

Midway through chapter 19 I started running into some issues with using a still-maturing language like Zig. Things change fast and documentation was not always easy to find. Eventually I ran into a problem where the compiler itself was panicking and having trouble printing its own error messages; I unfortunately lack the energy to track down compiler issues in a language I am still learning myself, so leaving this partially completed. I may return to this someday after Zig has had more time to bake. 
