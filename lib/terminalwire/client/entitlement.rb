require "pathname"

module Terminalwire::Client
  # Entitlements are the security boundary between the server and the client that lives on the client.
  # The server might request a file or directory from the client, and the client will check the entitlements
  # to see if the server is authorized to access the requested resource.
  module Entitlement
    # A policy has the authority, paths, and schemes that the server is allowed to access.
    class Policy
      attr_reader :paths, :authority, :schemes

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
      end

      def root_path
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
          storage_path: storage_path.to_s,
        }
      end
    end

    class RootPolicy < Policy
      AUTHORITY = "terminalwire.com".freeze

      # Ensure the binary stubs are executable. This increases the
      # file mode entitlement so that stubs created in ./bin are executable.
      BINARY_PATH_FILE_MODE = 0o755

      def initialize(*, **, &)
        # Make damn sure the authority is set to Terminalwire.
        super(*, authority: AUTHORITY, **, &)

        # Now setup special permitted paths.
        @paths.permit root_path
        @paths.permit root_pattern

        # Permit terminalwire to grant execute permissions to the binary stubs.
        @paths.permit binary_pattern, mode: BINARY_PATH_FILE_MODE
      end

      # Grant access to the `~/.terminalwire/**/*` path so users can install
      # terminalwire apps via `terminalwire install svbtle`, etc.
      def root_pattern
        root_path.join("**/*")
      end

      # Path where the terminalwire binary stubs are stored.
      def binary_path
        root_path.join("bin")
      end

      # Pattern for the binary path.
      def binary_pattern
        binary_path.join("*")
      end
    end

    def self.resolve(*, authority:, **, &)
      case authority
      when RootPolicy::AUTHORITY
        RootPolicy.new(*, **, &)
      else
        Policy.new *, authority:, **, &
      end
    end
  end
end
