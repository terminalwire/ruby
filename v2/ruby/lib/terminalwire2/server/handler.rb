# frozen_string_literal: true

module Terminalwire2
  module Server
    # The framework-agnostic server entrypoint. Given a transport and a Thor CLI
    # class, it performs the handshake, runs the requested command with a
    # Terminalwire-backed context, handles errors, and exits the client. A Rails
    # or Rack adapter just builds a transport and calls this.
    class Handler
      DEFAULT_ERROR_MESSAGE = "An error occurred. Please try again."

      # @param cli_class [Class] a Thor CLI that `include`s Server::Thor
      # @param report [#call, nil] optional callable invoked with unexpected errors
      # @param verbose [Boolean] show full backtraces to the client (dev only)
      def initialize(cli_class:, report: nil, verbose: false, error_message: DEFAULT_ERROR_MESSAGE)
        @cli_class = cli_class
        @report = report
        @verbose = verbose
        @error_message = error_message
      end

      # Run one session over the given transport. Returns the exit status.
      def call(transport:)
        runtime = Runtime.new(transport: transport).handshake
        context = Context.new(runtime)
        arguments = Array(runtime.program && runtime.program["args"])
        status = 0

        begin
          @cli_class.terminalwire(arguments: arguments, context: context) do |cli|
            yield cli, context if block_given?
          end
        rescue Interrupt
          status = 130
        rescue StandardError => e
          status = handle_error(e, context)
        ensure
          context.exit(status)
          runtime.close
        end

        status
      end

      private

      def handle_error(error, context)
        # Thor's own user-facing errors (unknown command, bad args) are friendly
        # already — pass them through verbatim.
        if defined?(::Thor::Error) && error.is_a?(::Thor::Error)
          context.warn(error.message)
        else
          @report&.call(error)
          context.warn(@verbose ? backtrace(error) : @error_message)
        end
        1
      end

      def backtrace(error)
        "#{error.class}: #{error.message}\n#{Array(error.backtrace).join("\n")}"
      end
    end
  end
end
