#!/usr/bin/env bash

ROOT_PATH="$(realpath "$(dirname "$0")")"
RUBY_PATH="$ROOT_PATH/vendor/bin/ruby"
BOOT_FILE_PATH="$ROOT_PATH/boot.rb"
ENTRYPOINT="$ROOT_PATH/app/exe/terminalwire"

# Preload boot.rb and then run the main application
exec "$RUBY_PATH" -r"$BOOT_FILE_PATH" "$ENTRYPOINT" "$@"
