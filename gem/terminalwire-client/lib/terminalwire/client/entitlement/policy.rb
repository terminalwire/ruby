module Terminalwire::Client::Entitlement
  module Policy
    # A policy has the authority, paths, and schemes that the server is allowed to access.
    class Base
      attr_reader :paths, :authority, :schemes, :environment_variables

      def initialize(authority:)
        @authority = authority
        @paths = Paths.new

        # Permit the domain directory. This is necessary for basic operation of the client.
        @paths.permit storage_path
        @paths.permit storage_pattern

        @schemes = Schemes.new
        # Permit http & https by default.
        @schemes.permit "http"
        @schemes.permit "https"

        @environment_variables = EnvironmentVariables.new
        # Permit the HOME and TERMINALWIRE_HOME environment variables.
        @environment_variables.permit "TERMINALWIRE_HOME"
      end

      def root_path
        # TODO: This needs to be passed into the Policy so that it can be set by the client.
        Terminalwire::Client.root_path
      end

      def authority_path
        root_path.join("authorities/#{authority}")
      end

      def storage_path
        authority_path.join("storage")
      end

      def storage_pattern
        storage_path.join("**/*")
      end

      def serialize
        {
          authority: @authority,
          schemes: @schemes.serialize,
          paths: @paths.serialize,
          environment_variables: @environment_variables.serialize
        }
      end
    end

    class Root < Base
      AUTHORITY = "terminalwire.com".freeze

      # Terminalwire checks these to install the binary stubs path.
      SHELL_INITIALIZATION_FILE_PATHS = %w[
        ~/.bash_profile
        ~/.bashrc
        ~/.zprofile
        ~/.zshrc
        ~/.profile
        ~/.config/fish/config.fish
        ~/.bash_login
        ~/.cshrc
        ~/.tcshrc
      ].freeze

      # Ensure the binary stubs are executable. This increases the
      # file mode entitlement so that stubs created in ./bin are executable.
      BINARY_PATH_FILE_MODE = 0o755

      def initialize(*, **, &)
        # Make damn sure the authority is set to Terminalwire.
        super(*, authority: AUTHORITY, **, &)

        # Now setup special permitted paths.
        @paths.permit root_path
        @paths.permit root_pattern
        # Permit the dotfiles so terminalwire can install the binary stubs.
        SHELL_INITIALIZATION_FILE_PATHS.each do |path|
          @paths.permit path
        end

        # Permit terminalwire to grant execute permissions to the binary stubs.
        @paths.permit binary_pattern, mode: BINARY_PATH_FILE_MODE

        # Used to check if terminalwire is setup in the user's PATH environment variable.
        @environment_variables.permit "PATH"

        # Permit the root path so we can check if the user has setup terminalwire. This
        # is used only during the installation script.
        @environment_variables.permit "TERMINALWIRE_ROOT"

        # Permit the shell environment variable so we can detect the user's shell.
        @environment_variables.permit "SHELL"
      end

      # Grant access to the `~/.terminalwire/**/*` path so users can install
      # terminalwire apps via `terminalwire install svbtle`, etc.
      def root_pattern
        root_path.join("**/*").freeze
      end

      # Path where the terminalwire binary stubs are stored.
      def binary_path
        root_path.join("bin").freeze
      end

      # Pattern for the binary path.
      def binary_pattern
        binary_path.join("*").freeze
      end
    end

    def self.resolve(*, authority:, **, &)
      case authority
      when Policy::Root::AUTHORITY
        Root.new(*, **, &)
      else
        Base.new *, authority:, **, &
      end
    end
  end
end
