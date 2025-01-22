require "uri"
require "yaml"

module Terminalwire
  # Generates Terminalwire binary file stubs. These files then run using
  # the `terminalwire-exec` command.
  class Binary
    SHEBANG = "#!/usr/bin/env terminalwire-exec".freeze

    ASSIGNABLE_KEYS = %w[url]

    attr_reader :url

    def initialize(url: nil)
      self.url = url if url
    end

    def url=(value)
      @url = URI(value)
    end

    def body
      <<~BASH
        #{SHEBANG}
        url: "#{url.to_s}"
      BASH
    end

    def assign(**hash)
      ASSIGNABLE_KEYS.each do |key|
        public_send "#{key}=", hash[key] if hash.key? key
      end
      self
    end

    # Writes the binary to the given path.
    def write(path)
      File.open(path, "w") do |file|
        file.write body
        file.chmod 0755
      end
    end

    def self.open(path)
      new.assign **YAML.safe_load_file(path)
    end

    def self.write(url:, to:)
      new(url: url).write to
    end
  end
end
