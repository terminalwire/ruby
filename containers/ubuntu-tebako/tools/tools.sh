#!/bin/bash

# Copyright (c) 2024 [Ribose Inc](https://www.ribose.com).
# All rights reserved.
# This file is a part of tamatebako
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
# TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR CONTRIBUTORS
# BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

set -o errexit -o pipefail -o noclobber -o nounset

: "${LOCAL_BUILDS:=/tmp/tebako}"
: "${CMAKE_VERSION:=3.24.4-1}"
: "${RUBY_VERSION:=3.3.6}"
: "${RUBY_INSTALL_VERSION:=0.9.3}"

install_cmake() {
  echo "Running install_cmake for CMake version ${CMAKE_VERSION}"

  # Detect system architecture and resolve cmake_arch
  case "$(uname -m)" in
    x86_64)
      cmake_arch="x64"
      ;;
    arm64 | aarch64)
      cmake_arch="arm64"
      ;;
    *)
      echo "Unsupported architecture: $(uname -m)"
      exit 1
      ;;
  esac

  echo "Detected architecture: $(uname -m), resolved cmake_arch: ${cmake_arch}"

  local cmake_install=${LOCAL_BUILDS}/cmake
  mkdir -p ${cmake_install}
  pushd ${cmake_install}
  wget -nv https://github.com/xpack-dev-tools/cmake-xpack/releases/download/v${CMAKE_VERSION}/xpack-cmake-${CMAKE_VERSION}-linux-${cmake_arch}.tar.gz
  tar -zxf xpack-cmake-${CMAKE_VERSION}-linux-${cmake_arch}.tar.gz --directory /usr --strip-components=1 --skip-old-files
  popd
  rm -rf ${cmake_install}
}

install_ruby() {
  echo "Running ruby_install version ${RUBY_INSTALL_VERSION} for Ruby ${RUBY_VERSION}"
  local ruby_install=${LOCAL_BUILDS}/ruby_install
  mkdir -p ${ruby_install}
  pushd ${ruby_install}
  wget -nv https://github.com/postmodern/ruby-install/releases/download/v${RUBY_INSTALL_VERSION}/ruby-install-${RUBY_INSTALL_VERSION}.tar.gz && \
  tar -xzvf ruby-install-${RUBY_INSTALL_VERSION}.tar.gz
  cd ruby-install-${RUBY_INSTALL_VERSION}
  make install
  ruby-install --system ruby ${RUBY_VERSION} -- --without-gmp --disable-dtrace --disable-debug-env --disable-install-doc CC=${CC}
  popd
  rm -rf ${ruby_install}
}

DIR0=$( dirname "$0" )
DIR_TOOLS=$( cd "$DIR0" && pwd )

echo "Running tools.sh with args: $@, DIR_TOOLS: ${DIR_TOOLS}"

"$@"
