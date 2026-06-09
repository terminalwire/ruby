# frozen_string_literal: true

require "simplecov"
SimpleCov.start do
  enable_coverage :branch
  add_filter "/spec/"
end

# Require the protocol core NARROWLY. The full `terminalwire/v2` entrypoint pulls
# the server runtime (and, transitively, the async/async-websocket stack) which we
# don't want in fast unit specs. These are the pure, sans-IO pieces the conformance
# corpus exercises directly.
require "terminalwire/v2/version"
require "terminalwire/v2/errors"
require "terminalwire/v2/protocol"
require "terminalwire/v2/codec"
require "terminalwire/v2/negotiator"
require "terminalwire/v2/frames"
require "terminalwire/v2/window"
require "terminalwire/v2/conformance"

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand config.seed
end
