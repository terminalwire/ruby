module Terminalwire
  module Server
    class WebSocket
      include Logging

      def call(env)
        Async::WebSocket::Adapters::Rack.open(env, protocols: ['ws']) do |connection|
          handle(
            adapter: Adapter::Socket.new(Terminalwire::Transport::WebSocket.new(connection)),
            env:
          )
        end or [200, { "Content-Type" => "text/plain" }, ["Connect via WebSockets"]]
      end

      def handle(adapter:, env:)
        while message = adapter.read
          puts message
        end
      end
    end
  end
end
