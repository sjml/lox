#!/bin/sh

echo "Building..."
dub build --build=release > /dev/null
mv ./dlox ./dlox-slow
dub build --build=release --config=with-optimizations > /dev/null
mv ./dlox ./dlox-fast

echo "ZOO BEFORE:"
./dlox-slow ../test/programs/zoo.lox

echo "ZOO OPTIMIZED:"
./dlox-fast ../test/programs/zoo.lox

# echo "TEST SUIT BEFORE:"
# pushd ../test/tmp/craftinginterpreters/ > /dev/null
#   time dart ./tool/bin/test.dart clox --interpreter ../../../dlox/dlox-slow
# popd > /dev/null

# echo "TEST SUIT OPTIMIZED:"
# pushd ../test/tmp/craftinginterpreters/ > /dev/null
#   time dart ./tool/bin/test.dart clox --interpreter ../../../dlox/dlox-fast
# popd > /dev/null

