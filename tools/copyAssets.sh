#!/usr/bin/env bash
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

if [ ! -d "${SCRIPT_DIR}/zig-out/bin" ]; then
    mkdir "${SCRIPT_DIR}/zig-out/bin"
fi

cp -r "${SCRIPT_DIR}/assets" "${SCRIPT_DIR}/zig-out/bin/"
echo "Copied assets to zig-out."
