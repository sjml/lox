#!/usr/bin/env bash

set -e

cd "$(dirname "$0")"

for opt in Debug ReleaseSafe ReleaseFast ReleaseSmall; do
  zig build -Doptimize=$opt
  mv ./zig-out/bin/zlox ./zig-out/bin/zlox-$opt
done
