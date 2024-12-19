ROOT_PATH=$PWD

# Setup paths
BUILD_PATH="$ROOT_PATH/build"

# Where Ruby and gems are installed.
VENDOR_PATH="$BUILD_PATH/vendor"

# Add the Ruby binary to the path.
APP_PATH="$BUILD_PATH/app"

# Source code that we're packing up.'
SOURCE_PATH="$ROOT_PATH/gem/terminalwire"

# Ruby version to install and bundle with the package.
RUBY_VERSION="3.3.6"

# Install Ruby in the vendor directory.
if [ -d "$VENDOR_PATH" ]; then
  echo "Ruby already installed at $VENDOR_PATH. Skipping build process."
else
  echo "Ruby not found. Starting build process..."
  # Make the directories if they don't exist
  mkdir -p $VENDOR_PATH
  ruby-install ruby "$RUBY_VERSION" --install-dir "$(realpath "$VENDOR_PATH")"
fi

cp -r $SOURCE_PATH $APP_PATH

# Now setup gem paths to point to the $VENDOR_PATH gems directory.
export GEM_HOME="$VENDOR_PATH/gems"
export GEM_PATH=$GEM_HOME
export PATH="$VENDOR_PATH/bin:$PATH" # Add the Ruby binary to the path.
export BUNDLE_GEMFILE="Gemfile.exe"

# Change into the path
pushd $APP_PATH

# Bundle the gems
bundle install
