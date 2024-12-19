ROOT_PATH="$(dirname "$0")"

# Setup paths
BUILD_PATH="$PWD/build"

### Copy the package template into the build directory
cp -rv "$ROOT_PATH/template/" "$BUILD_PATH"

# Remove all the .gitkeep files
rm "$BUILD_PATH"/**/.gitkeep

# Where Ruby and gems are installed.
VENDOR_PATH="$BUILD_PATH/vendor"

# Add the Ruby binary to the path.
APP_PATH="$BUILD_PATH/app"

# Source code that we're packing up.
SOURCE_PATH="$PWD/gem/terminalwire"

# Ruby version to install and bundle with the package.
RUBY_VERSION="3.3.6"

### Build Ruby

# Install Ruby in the vendor directory.
ruby-install ruby "$RUBY_VERSION" --install-dir "$(realpath "$VENDOR_PATH")"

### Install dependencies

cp -r "$SOURCE_PATH/" "$APP_PATH"

# Now setup gem paths to point to the $VENDOR_PATH gems directory.
export GEM_HOME="$VENDOR_PATH/gems"
export GEM_PATH="$GEM_HOME"
export PATH="$VENDOR_PATH/bin:$PATH" # Add the Ruby binary to the path.
export BUNDLE_GEMFILE="$APP_PATH/Gemfile.exe"

# Change into the app path
pushd "$APP_PATH"

# Bundle the gems
bundle install

popd

### Install the shim scripts

shim() {
  local entrypoint="$1"
  local shim_path="$BUILD_PATH/bin/$(basename "$entrypoint")"
  local boot_path="$BUILD_PATH/lib/boot.sh"

  mkdir -p "$(dirname "$shim_path")"

  # Create the shim script
  cat <<EOF > "$shim_path"
#!/usr/bin/env bash
BOOT_DIR="\$(dirname "\$(realpath "\$0")")/../lib"
exec "\$BOOT_DIR/boot.sh" "$entrypoint" "\$@"
EOF

  # Make the shim executable
  chmod +x "$shim_path"
  echo "Shim created at $shim_path"
}

# Example usage of shim function
shim "exe/terminalwire"
