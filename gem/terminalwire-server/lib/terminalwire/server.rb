require "terminalwire"
require "terminalwire/logging"

module Terminalwire
  module Server
    Loader = Zeitwerk::Loader.new.tap do |it|
      it.push_dir File.join(__dir__, "server"), namespace: self
      it.setup
    end

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
