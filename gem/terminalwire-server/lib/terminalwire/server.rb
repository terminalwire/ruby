require "terminalwire"
require "terminalwire/logging"

require "zeitwerk"
Zeitwerk::Loader.for_gem_extension(Terminalwire).tap do |loader|
  loader.setup
end

module Terminalwire
  module Server
  end
end
