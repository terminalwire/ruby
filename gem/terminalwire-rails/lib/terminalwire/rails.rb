require "terminalwire-server"
require "thor"
require "rails"
require "jwt"

module Terminalwire
  module Rails
    class Session
      # JWT file name for the session file.
      FILENAME = "session.jwt"

      # Empty dictionary the user can stash all their session data into.
      EMPTY_SESSION = {}.freeze

      extend Forwardable

      # Delegate `dig` and `fetch` to the `read` method
      def_delegators :read,
        :dig, :fetch, :[]

      def initialize(context:, path: nil, secret_key: self.class.secret_key)
        @context = context
        @path = Pathname.new(path || context.storage_path)
        @config_file_path = @path.join(FILENAME)
        @secret_key = secret_key

        ensure_file
      end

      def read
        jwt_token = @context.file.read(@config_file_path)
        decoded_data = JWT.decode(jwt_token, @secret_key, true, algorithm: 'HS256')
        decoded_data[0]  # JWT payload is the first element in the array
      rescue JWT::DecodeError => e
        raise "Invalid or tampered file: #{e.message}"
      end

      def reset
        @context.file.delete @config_file_path
      end

      def edit
        config = read
        yield config
        write(config)
      end

      def []=(key, value)
        edit { |config| config[key] = value }
      end

      def write(config)
        token = JWT.encode(config, @secret_key, 'HS256')
        @context.file.write(@config_file_path, token)
      end

      private

      def ensure_file
        return true if @context.file.exist? @config_file_path
        # Create the path if it doesn't exist on the client.
        @context.directory.create @path
        # Write an empty configuration on initialization
        write(EMPTY_SESSION)
      end

      def self.secret_key
        ::Rails.application.secret_key_base
      end
    end

    class Thor < Server::WebSocket
      include Logging

      def initialize(cli_class)
        @cli_class = cli_class

        unless @cli_class.included_modules.include?(Terminalwire::Server::Thor)
          raise 'Add `include Terminalwire::Server::Thor` to the #{@cli_class.inspect} class.'
        end
      end

      def error_message
        "An error occurred. Please try again."
      end

      def handle(adapter:, env:)
        logger.info "ThorServer: Running #{@cli_class.inspect}"
        while message = adapter.read
          case message
          in { event: "initialization", protocol:, program: { arguments: }, entitlement: }
            context = Terminalwire::Server::Context.new(adapter:, entitlement:)
            exit_code = 0

            begin
              @cli_class.terminalwire arguments:, context: do |cli|
                cli.default_url_options = { host: env["HTTP_HOST"] }
              end
            rescue ::Thor::UndefinedCommandError, ::Thor::InvocationError => e
              context.stdout.puts e.message
            rescue ::StandardError => e
              # Log the error
              handler_error_message = <<~ERROR
                #{e.class.name} (#{e.message})

                #{e.backtrace.join("\n")}
              ERROR

              ::Rails.logger.error(handler_error_message)
              # Report the error to Rails' notification system
              ::Rails.error.report(e, handled: true)

              if ::Rails.application.config.consider_all_requests_local
                # Show the full error message with stack trace in development
                context.stderr.puts handler_error_message
              else
                # Show a generic message in production
                context.stderr.puts error_message
              end
              exit_code = 1
            ensure
              context.exit exit_code
            end
          end
        end
      end
    end
  end

  # If I move this, then the current production integration breaks because
  # it wants `include Terminalwire::Thor`.
  module Thor
    class Shell < Terminalwire::Server::Thor::Shell
      attr_reader :session

      def initialize(context, *, **, &)
        @session = Terminalwire::Rails::Session.new(context:)
        super(context, *,**,&)
      end
    end

    def self.included(base)
      base.include Terminalwire::Server::Thor
      base.extend ClassMethods

      # I have to do this in a block to deal with some of Thor's DSL
      base.class_eval do
        protected

        no_commands do
          def_delegators :shell,
            :session

          include ::Rails.application.routes.url_helpers
        end
      end
    end

    module ClassMethods
      # Use the extend Rails shell with this shell
      def terminalwire_shell(context)
        Terminalwire::Thor::Shell.new(context)
      end
    end
  end
end
