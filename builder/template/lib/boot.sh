#!/usr/bin/env bash

# Resolve the directory of this script
BOOT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Paths relative to the resolved BOOT_DIR
RUBY_PATH="$BOOT_DIR/../vendor/bin/ruby"
BOOT_FILE_PATH="$BOOT_DIR/boot.rb"

# Accept entry point as the first argument
RELATIVE_ENTRYPOINT="$1"
shift # Shift positional arguments so $@ contains only user-provided arguments

# Make the ENTRYPOINT absolute and prepend 'app'
ENTRYPOINT="$BOOT_DIR/../app/$RELATIVE_ENTRYPOINT"

# Run Ruby with boot.rb and the entrypoint
exec "$RUBY_PATH" -r"$BOOT_FILE_PATH" "$ENTRYPOINT" "$@"
