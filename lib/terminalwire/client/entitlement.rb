module Terminalwire::Client
  module Entitlement
    class Paths
      include Enumerable

      def initialize
        @permitted = []
      end

      def each(&)
        @permitted.each(&)
      end

      def permit(path)
        @permitted.append Pathname.new(path).expand_path
      end

      def permitted?(path)
        @permitted.find { |pattern| matches?(permitted: pattern, path:) }
      end

      def serialize
        @permitted.to_a.map(&:to_s)
      end

      private
      def matches?(permitted:, path:)
        # This MUST be done via File.fnmatch because Pathname#fnmatch does not work. If you
        # try changing this 🚨 YOU MAY CIRCUMVENT THE SECURITY MEASURES IN PLACE. 🚨
        File.fnmatch permitted.to_s, File.expand_path(path), File::FNM_PATHNAME
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
        @paths.permit root_pattern
      end

      # Grant access to the `~/.terminalwire/**/*` path so users can install
      # terminalwire apps via `terminalwire install svbtle`, etc.
      def root_pattern
        root_path.join("**/*")
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
