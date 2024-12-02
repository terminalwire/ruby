require "terminalwire-server"
require "thor"
require "rails"

module Terminalwire
  module Rails
    class Thor < Server::WebSocket
      Rails = ::Rails

      include Logging

      def initialize(cli_class)
        @cli_class = cli_class

        unless @cli_class.included_modules.include?(Terminalwire::Thor)
          raise 'Add `include Terminalwire::Thor` to the #{@cli_class.inspect} class.'
        end
      end

      def error_message
        "An error occurred. Please try again."
      end

      def handle(adapter)
        logger.info "ThorServer: Running #{@cli_class.inspect}"
        while message = adapter.read
          case message
          in { event: "initialization", protocol:, program: { arguments: }, entitlement: }
            context = Terminalwire::Server::Context.new(adapter:, entitlement:)

            begin
              @cli_class.start(arguments, context:)
              context.exit
            rescue StandardError => e
              if Rails.application.config.consider_all_requests_local
                # Show the full error message with stack trace in development
                context.stderr.puts "#{e.inspect}\n#{e.backtrace.join("\n")}"
              else
                # Show a generic message in production
                context.stderr.puts error_message
              end
              context.exit 1
            end
          end
        end
      end
    end
  end
end
