require 'logger'

module Terminalwire
  module Logging
    DEVICE = Logger.new($stdout, level: ENV.fetch("TERMINALWIRE_LOG_LEVEL", "info"))
    def logger = DEVICE
  end
end
