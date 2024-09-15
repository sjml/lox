#!/usr/bin/env bash

cd "$(dirname "$0")"

dfmt \
  --inplace \
  --brace_style otbs \
  source/*.d
