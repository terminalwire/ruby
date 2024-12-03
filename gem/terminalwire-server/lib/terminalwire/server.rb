require "terminalwire"
require "terminalwire/logging"

require "zeitwerk"
Zeitwerk::Loader.for_gem_extension(Terminalwire).tap do |loader|
  loader.setup
end

module Terminalwire
  module Server
    class WebSocket
      include Logging

      def call(env)
        Async::WebSocket::Adapters::Rack.open(env, protocols: ['ws']) do |connection|
          handle(Adapter::Socket.new(Terminalwire::Transport::WebSocket.new(connection)))
        end or [200, { "Content-Type" => "text/plain" }, ["Connect via WebSockets"]]
      end

      def handle(adapter)
        while message = adapter.read
          puts message
        end
      end
    end
  end
end
