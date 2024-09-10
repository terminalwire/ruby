require "pathname"
require "yaml"
require "uri"

module Terminalwire::Client
  class Exec
    attr_reader :arguments, :path, :configuration, :url

    def initialize(path:, arguments:)
      @arguments = arguments
      @path = Pathname.new(path)
      @configuration = YAML.load_file(@path)
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
