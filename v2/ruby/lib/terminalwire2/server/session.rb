# frozen_string_literal: true

module Terminalwire2
  module Server
    # Adapts a callback/event-loop websocket endpoint to the blocking Handler.
    # The endpoint supplies an `on_send` sink for outgoing frames and forwards
    # each incoming frame to #receive; the CLI runs on a background thread. This is
    # the seam an ActionCable channel or an async-websocket Rack endpoint plugs
    # into (see ../../../README.md).
    #
    #   session = Terminalwire2::Server::Session.start(
    #     cli_class: MyCLI,
    #     on_send:   ->(bytes) { websocket.send_binary(bytes) }
    #   )
    #   websocket.on_message { |bytes| session.receive(bytes) }
    #   websocket.on_close   { session.close }
    class Session
      def self.start(cli_class:, on_send:, report: nil, verbose: false)
        new(cli_class: cli_class, on_send: on_send, report: report, verbose: verbose).tap(&:start)
      end

      def initialize(cli_class:, on_send:, report: nil, verbose: false)
        @transport = Transport::Queue.new(sink: on_send)
        @handler = Handler.new(cli_class: cli_class, report: report, verbose: verbose)
      end

      def start
        @thread = Thread.new { @handler.call(transport: @transport) }
        self
      end

      # Forward a frame received from the client.
      def receive(bytes)
        @transport.deliver(bytes)
      end

      # End the session and wait briefly for the worker to finish.
      def close
        @transport.close
        @thread&.join(2)
      end
    end
  end
end
