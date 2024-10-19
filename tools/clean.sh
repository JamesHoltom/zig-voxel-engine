#!/usr/bin/env bash
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

rm -r ${SCRIPT_DIR}/../{.zig-cache,zig-out}/*
echo "Cleaned cache and output."
