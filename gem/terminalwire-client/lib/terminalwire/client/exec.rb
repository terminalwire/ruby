require "pathname"
require "yaml"
require "uri"

module Terminalwire::Client
  # Called by the `terminalwire-exec` shebang in scripts. This makes it easy for people
  # to create their own scripts that use Terminalwire that look like this:
  #
  # ```sh
  # #!/usr/bin/env terminalwire-exec
  # url: "https://terminalwire.com/terminal"
  # ```
  #
  # These files are saved, then `chmod + x` is run on them and they become executable.
  class Exec
    attr_reader :arguments, :path, :configuration, :url

    def initialize(path:, arguments:)
      @arguments = arguments
      @path = Pathname.new(path)
      @configuration = YAML.safe_load_file(@path)
      @url = URI(@configuration.fetch("url"))
    rescue Errno::ENOENT => e
      raise Terminalwire::Error, "File not found: #{@path}"
    rescue URI::InvalidURIError => e
      raise Terminalwire::Error, "Invalid URI: #{@url}"
    rescue KeyError => e
      raise Terminalwire::Error, "Missing key in configuration: #{e}"
    end

    def start
      Terminalwire::Client.websocket(url:, arguments:)
    end

    def self.start
      case ARGV
      in path, *arguments
        new(path:, arguments:).start
      end
    rescue NoMatchingPatternError => e
      raise Terminalwire::Error, "Launched with incorrect arguments: #{ARGV}"
    end
  end
end
