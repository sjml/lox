#!/usr/bin/env bash

ROOT_PATH="$(dirname "$0")"

PYTHONPATH="$ROOT_PATH" exec python -m plox $@
