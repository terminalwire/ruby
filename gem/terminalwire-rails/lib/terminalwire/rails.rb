# frozen_string_literal: true

# terminalwire-rails 2.x: the v2 Rails integration.
#
# Bundler auto-requires this for `gem "terminalwire-rails"`. It loads the v2 server
# and defines the v1 API names backed by v2 (see terminalwire/v2/rails.rb):
#
#   * Terminalwire::Thor          -> the v2 Rails terminal mixin (include in your CLI)
#   * Terminalwire::Rails::Thor   -> the v2 Rack handler (mount in routes)
#   * Terminalwire::Rails::Session -> the v2 JWT client session
#
# So a 1.x/0.x app upgrades to v2 by bumping this gem to "~> 2.0" and redeploying —
# its unchanged `include Terminalwire::Thor` and
# `match "/terminal", to: Terminalwire::Rails::Thor.new(MainTerminal)` now serve v2.
require "terminalwire/v2/rails"
