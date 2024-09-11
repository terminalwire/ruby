module Terminalwire
  module Client
    module Resource
      class Base < Terminalwire::Resource::Base
        def dispatch(command, **data)
          respond self.public_send(command, **data)
        end
      end

      class STDOUT < Base
        def connect
          @device = $stdout
        end

        def print(data:)
          @device.print(data)
        end

        def print_line(data:)
          @device.puts(data)
        end
      end

      class STDERR < STDOUT
        def connect
          @device = $stderr
        end
      end

      class STDIN < Base
        def connect
          @device = $stdin
        end

        def read_line
          @device.gets
        end

        def read_password
          @device.getpass
        end
      end

      class File < Base
        File = ::File
        ALLOWED_PATH = File.expand_path("~/.terminalwire")

        def read(path:)
          File.read File.expand_path(path)
        end

        def write(path:, content:)
          File.open(File.expand_path(path), "w") { |f| f.write(content) }
        end

        def append(path:, content:)
          File.open(File.expand_path(path), "a") { |f| f.write(content) }
        end

        def mkdir(path:)
          FileUtils.mkdir_p(File.expand_path(path))
        end

        def exist(path:)
          File.exist? File.expand_path(path)
        end

        def dispatch(command, path:, **data)
          if allowed?(path:)
            super(command, path: File.expand_path(path), **data)
          else
            respond("Access to #{path} is not allowed by client", status: "failure")
          end
        end

        protected

        def allowed?(path:)
          File.expand_path(path).start_with?(ALLOWED_PATH)
        end
      end

      class Browser < Base
        def launch(url:)
          Launchy.open(URI(url))
          # TODO: This is a hack to get the `respond` method to work.
          # Maybe explicitly call a `suceed` and `fail` method?
          nil
        end
      end
    end

    class ResourceMapper
      def initialize(adapter, resources)
        @adapter = adapter
        @resources = resources
        @devices = {}
      end

      def connect_device(type)
        klass = @resources.find(type)
        if klass
          device = klass.new(type, @adapter)
          device.connect
          @devices[type] = device
          @adapter.write(event: "device", action: "connect", status: "success", name: type, type: type)
        else
          @adapter.write(event: "device", action: "connect", status: "failure", name: type, type: type, message: "Unknown device type")
        end
      end

      def dispatch(name, action, data)
        device = @devices[name]
        if device
          device.dispatch(action, **data)
        else
          raise "Unknown device: #{name}"
        end
      end

      def disconnect_device(name)
        device = @devices.delete(name)
        device&.disconnect
        @adapter.write(event: "device", action: "disconnect", name: name)
      end
    end

    class Handler
      VERSION = "0.1.0".freeze

      include Logging

      attr_reader :arguments, :program_name

      def initialize(adapter, resources = self.class.resources, arguments: ARGV, program_name: $0)
        @adapter = adapter
        @resources = resources
        @arguments = arguments
        @program_name = program_name
      end

      def connect
        @devices = ResourceMapper.new(@adapter, @resources)

        @adapter.write(event: "initialize", protocol: { version: VERSION }, arguments:, program_name:)

        loop do
          handle @adapter.recv
        end
      end

      def handle(message)
        case message
        in { event: "device", action: "connect", name:, type: }
          @devices.connect_device(type)
        in { event: "device", action: "command", name:, command:, **data }
          @devices.dispatch(name, command, data)
        in { event: "device", action: "disconnect", name: }
          @devices.disconnect_device(name)
        in { event: "exit", status: }
          exit Integer(status)
        end
      end

      def self.resources
        ResourceRegistry.new.tap do |resources|
          resources << Client::Resource::STDOUT
          resources << Client::Resource::STDIN
          resources << Client::Resource::STDERR
          resources << Client::Resource::Browser
          resources << Client::Resource::File
        end
      end
    end

    def self.tcp(...)
      socket = TCPSocket.new(...)
      transport = Terminalwire::Transport::Socket.new(socket)
      adapter = Terminalwire::Adapter.new(transport)
      Terminalwire::Client::Handler.new(adapter)
    end

    def self.socket(...)
      socket = UNIXSocket.new(...)
      transport = Terminalwire::Transport::Socket.new(socket)
      adapter = Terminalwire::Adapter.new(transport)
      Terminalwire::Client::Handler.new(adapter)
    end

    def self.websocket(url:, arguments: ARGV)
      url = URI(url)

      Async do |task|
        endpoint = Async::HTTP::Endpoint.parse(url)

        Async::WebSocket::Client.connect(endpoint) do |adapter|
          transport = Terminalwire::Transport::WebSocket.new(adapter)
          adapter = Terminalwire::Adapter.new(transport)
          Terminalwire::Client::Handler.new(adapter, arguments:).connect
        end
      end
    end
  end
end
