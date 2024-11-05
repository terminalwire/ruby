module Terminalwire::Client
  # The handler is the main class that connects to the Terminalwire server and
  # dispatches messages to the appropriate resources.
  class Handler
    VERSION = "0.1.0".freeze

    include Terminalwire::Logging

    attr_reader :adapter, :resources, :endpoint
    attr_accessor :entitlement

    def initialize(adapter, arguments: ARGV, program_name: $0, endpoint:)
      @endpoint = endpoint
      @adapter = adapter
      @program_arguments = arguments
      @program_name = program_name
      @entitlement = Entitlement::Policy.resolve(authority: @endpoint.authority)

      yield self if block_given?

      @resources = Resource::Handler.new do |it|
        it << Resource::STDOUT.new("stdout", @adapter, entitlement:)
        it << Resource::STDIN.new("stdin", @adapter, entitlement:)
        it << Resource::STDERR.new("stderr", @adapter, entitlement:)
        it << Resource::Browser.new("browser", @adapter, entitlement:)
        it << Resource::File.new("file", @adapter, entitlement:)
        it << Resource::Directory.new("directory", @adapter, entitlement:)
      end
    end

    def verify_license
      # Connect to the Terminalwire license server to verify the URL endpoint
      # and displays a message to the user, if any are present.
      $stdout.print ServerLicenseVerification.new(url: @endpoint.to_url).message
    rescue
      $stderr.puts "Failed to verify server license."
    end

    def connect
      verify_license

      @adapter.write(
        event: "initialization",
        protocol: { version: VERSION },
        entitlement: @entitlement.serialize,
        program: {
          name: @program_name,
          arguments: @program_arguments
        }
      )

      loop do
        handle @adapter.read
      end
    end

    def handle(message)
      case message
      in { event: "resource", action: "command", name:, parameters: }
        @resources.dispatch(**message)
      in { event: "exit", status: }
        exit Integer(status)
      end
    end
  end
end
