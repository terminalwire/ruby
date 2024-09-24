require "pathname"

module Terminalwire::Client
  module Entitlement
    class Paths
      class Permit
        attr_reader :path, :mode
        # Ensure the default file mode is read/write for owner only. This ensures
        # that if the server tries uploading an executable file, it won't be when it
        # lands on the client.
        #
        # Eventually we'll move this into entitlements so the client can set maximum
        # permissions for files and directories.
        MODE = 0o600 # rw-------

        # Constants for permission bit masks
        OWNER_PERMISSIONS = 0o700 # rwx------
        GROUP_PERMISSIONS = 0o070 # ---rwx---
        OTHERS_PERMISSIONS = 0o007 # ------rwx

        # We'll validate that modes are within this range.
        MODE_RANGE = 0o000..0o777

        def initialize(path:, mode: MODE)
          @path = Pathname.new(path).expand_path
          @mode = convert(mode)
        end

        def permitted_path?(path)
          # This MUST be done via File.fnmatch because Pathname#fnmatch does not work. If you
          # try changing this 🚨 YOU MAY CIRCUMVENT THE SECURITY MEASURES IN PLACE. 🚨
          File.fnmatch @path.to_s, File.expand_path(path), File::FNM_PATHNAME
        end

        def permitted_mode?(value)
          # Ensure the mode is at least as permissive as the permitted mode.
          mode = convert(value)

          # Extract permission bits for owner, group, and others
          owner_bits = mode & OWNER_PERMISSIONS
          group_bits = mode & GROUP_PERMISSIONS
          others_bits = mode & OTHERS_PERMISSIONS

          # Ensure that the mode doesn't grant more permissions than @mode in any class (owner, group, others)
          (owner_bits <= @mode & OWNER_PERMISSIONS) &&
          (group_bits <= @mode & GROUP_PERMISSIONS) &&
          (others_bits <= @mode & OTHERS_PERMISSIONS)
        end

        def permitted?(path:, mode: @mode)
          permitted_path?(path) && permitted_mode?(mode)
        end

        def serialize
          {
            location: @path.to_s,
            mode: @mode
          }
        end

        protected
        def convert(value)
          mode = Integer(value)
          raise ArgumentError, "The mode #{format_octet value} must be an octet value between #{format_octet MODE_RANGE.first} and #{format_octet MODE_RANGE.last}" unless MODE_RANGE.cover?(mode)
          mode
        end

        def format_octet(value)
          format("0o%03o", value)
        end
      end

      include Enumerable

      def initialize
        @permitted = []
      end

      def each(&)
        @permitted.each(&)
      end

      def permit(path, **)
        @permitted.append Permit.new(path:, **)
      end

      def permitted?(path)
        find { |permit| permit.permitted_path?(path) }
      end

      def serialize
        map(&:serialize)
      end
    end

    class Schemes
      include Enumerable

      def initialize
        @permitted = Set.new
      end

      def each(&)
        @permitted.each(&)
      end

      def permit(scheme)
        @permitted << scheme.to_s
      end

      def permitted?(url)
        include? URI(url).scheme
      end

      def serialize
        @permitted.to_a.map(&:to_s)
      end
    end

    class Policy
      attr_reader :paths, :authority, :schemes

      ROOT_PATH = "~/.terminalwire".freeze

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
        Pathname.new(ROOT_PATH)
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
      HOST = "terminalwire.com".freeze

      def initialize(*, **, &)
        # Make damn sure the authority is set to Terminalwire.
        super(*, authority: HOST, **, &)

        # Now setup special permitted paths.
        @paths.permit root_path
        @paths.permit root_pattern

        # Permit terminalwire to grant execute permissions to the binary stubs.
        @paths.permit binary_pattern, mode: 0755
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

    def self.from_url(url)
      url = URI(url)

      case url.host
      when RootPolicy::HOST
        RootPolicy.new
      else
        Policy.new authority: url_authority(url)
      end
    end

    def self.url_authority(url)
      # I had to lift this from URI::HTTP because `ws://` doesn't
      # have an authority method.
      if url.port == url.default_port
        url.host
      else
        "#{url.host}:#{url.port}"
      end
    end
  end
end
