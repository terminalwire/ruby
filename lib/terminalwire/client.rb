module Terminalwire
  module Client
    module Resource
      class IO < Terminalwire::Resource::Base
        def dispatch(action, data)
          if @device.respond_to?(action)
            respond @device.public_send(action, data)
          else
            raise "Unknown action #{action} for device ID #{@id}"
          end
        end

        def prints(data:)
        end

        def puts(data:)
        end
      end

      class STDOUT < IO
        def connect
          @device = $stdout
        end
      end

      class STDIN < IO
        def connect
          @device = $stdin
        end

        def dispatch(action, data)
          respond case action
          when "puts"
            @device.puts(data)
          when "gets"
            @device.gets
          when "getpass"
            @device.getpass
          end
        end
      end

      class STDERR < IO
        def connect
          @device = $stderr
        end
      end

      class File < Terminalwire::Resource::Base
        def connect
          @files = {}
        end

        def dispatch(action, data)
          respond case action
          when "read"
            read_file(data)
          when "write"
            write_file(data.fetch(:path), data.fetch(:content))
          when "append"
            append_to_file(data.fetch(:path), data.fetch(:content))
          when "mkdir"
            mkdir(data.fetch(:path))
          when "exist"
            exist?(data.fetch(:path))
          else
            raise "Unknown action #{action} for file device"
          end
        end

        def mkdir(path)
          FileUtils.mkdir_p(::File.expand_path(path))
        end

        def exist?(path)
          ::File.exist? ::File.expand_path(path)
        end

        def read_file(path)
          ::File.read ::File.expand_path(path)
        end

        def write_file(path, content)
          ::File.open(::File.expand_path(path), "w") { |f| f.write(content) }
        end

        def append_to_file(path, content)
          ::File.open(::File.expand_path(path), "a") { |f| f.write(content) }
        end

        def disconnect
          @files.clear
        end
      end

      class Browser < Terminalwire::Resource::Base
        def dispatch(action, data)
          respond case action
          when "launch"
            Launchy.open(data)
            "Launched browser with URL: #{data}"
          else
            raise "Unknown action #{action} for browser device"
          end
        end
      end
    end

    class ResourceMapper
      def initialize(connection, resources)
        @connection = connection
        @resources = resources
        @devices = Hash.new { |h,k| h[Integer(k)] }
      end

      def connect_device(id, type)
        klass = @resources.find(type)
        if klass
          device = klass.new(id, @connection)
          device.connect
          @devices[id] = device
          @connection.write(event: "device", action: "connect", status: "success", id: id, type: type)
        else
          @connection.write(event: "device", action: "connect", status: "failure", id: id, type: type, message: "Unknown device type")
        end
      end

      def dispatch(id, action, data)
        device = @devices[id]
        if device
          device.dispatch(action, data)
        else
          raise "Unknown device ID: #{id}"
        end
      end

      def disconnect_device(id)
        device = @devices.delete(id)
        device&.disconnect
        @connection.write(event: "device", action: "disconnect", id: id)
      end
    end

    class Handler
      VERSION = "0.1.0".freeze

      include Logging

      attr_reader :arguments, :program_name

      def initialize(connection, resources = self.class.resources, arguments: ARGV, program_name: $0)
        @connection = connection
        @resources = resources
        @arguments = arguments
      end

      def connect
        @devices = ResourceMapper.new(@connection, @resources)

        @connection.write(event: "initialize", protocol: { version: VERSION }, arguments:, program_name:)

        loop do
          handle @connection.recv
        end
      end

      def handle(message)
        case message
        in { event: "device", action: "connect", id:, type: }
          @devices.connect_device(id, type)
        in { event: "device", action: "command", id:, command:, data: }
          @devices.dispatch(id, command, data)
        in { event: "device", action: "disconnect", id: }
          @devices.disconnect_device(id)
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
      connection = Terminalwire::Connection.new(transport)
      Terminalwire::Client::Handler.new(connection)
    end

    def self.socket(...)
      socket = UNIXSocket.new(...)
      transport = Terminalwire::Transport::Socket.new(socket)
      connection = Terminalwire::Connection.new(transport)
      Terminalwire::Client::Handler.new(connection)
    end

    def self.websocket(url:, arguments: ARGV)
      url = URI(url)

      Async do |task|
        endpoint = Async::HTTP::Endpoint.parse(url)

        Async::WebSocket::Client.connect(endpoint) do |connection|
          transport = Terminalwire::Transport::WebSocket.new(connection)
          connection = Terminalwire::Connection.new(transport)
          Terminalwire::Client::Handler.new(connection, arguments:).connect
        end
      end
    end
  end
end
