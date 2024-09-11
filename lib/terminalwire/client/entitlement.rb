module Terminalwire::Client
  class Entitlement
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

      private
      def matches?(permitted:, path:)
        # This MUST be done via File.fnmatch because Pathname#fnmatch does not work. If you
        # try changing this 🚨 YOU MAY CIRCUMVENT THE SECURITY MEASURES IN PLACE. 🚨
        File.fnmatch permitted.to_s, File.expand_path(path), File::FNM_PATHNAME
      end
    end

    attr_reader :paths, :authority

    def initialize(authority:)
      @authority = authority
      @paths = Paths.new
      # Permit the domain directory. This is necessary for basic operation of the client.
      @paths.permit domain_path
    end

    def domain_path
      Pathname.new("~/.terminalwire/domains/#{@authority}/files/**/*").expand_path
    end

    def self.from_url(url)
      # I had to lift this from URI::HTTP because `ws://` doesn't
      # have an authority method.
      authority = if url.port == url.default_port
        url.host
      else
        "#{url.host}:#{url.port}"
      end

      new authority:
    end
  end
end
