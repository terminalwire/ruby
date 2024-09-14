module Terminalwire
  module Client
    module Resource
      class Base < Terminalwire::Resource::Base
        def initialize(*, entitlement:, **)
          super(*, **)
          @entitlement = entitlement
        end

        def dispatch(command, **data)
          respond self.public_send(command, **data)
        end
      end

      class STDOUT < Base
        def connect
          @io = $stdout
        end

        def print(data:)
          @io.print(data)
        end

        def print_line(data:)
          @io.puts(data)
        end
      end

      class STDERR < STDOUT
        def connect
          @io = $stderr
        end
      end

      class STDIN < Base
        def connect
          @io = $stdin
        end

        def read_line
          @io.gets
        end

        def read_password
          @io.getpass
        end
      end

      class File < Base
        File = ::File

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
          if @entitlement.paths.permitted? path
            super(command, path: File.expand_path(path), **data)
          else
            respond("Access to #{path} denied", status: "failure")
          end
        end

        protected

        def allowed?(path:)
          File.expand_path(path).start_with?(ALLOWED_PATH)
        end
      end

      class Browser < Base
        def dispatch(command, url:, **data)
          if @entitlement.schemes.permitted? url
            super(command, url:, **data)
          else
            respond("Access to #{url} denied", status: "failure")
          end
        end

        def launch(url:)
          Launchy.open(URI(url))
          # TODO: This is a hack to get the `respond` method to work.
          # Maybe explicitly call a `suceed` and `fail` method?
          nil
        end
      end
    end

    class ResourceMapper
      def initialize(adapter:, entitlement:)
        @adapter = adapter
        @entitlement = entitlement
        @resources = {}
      end

      def connect_resource(type)
        klass = case type
        when "stdout" then Client::Resource::STDOUT
        when "stdin" then Client::Resource::STDIN
        when "stderr" then Client::Resource::STDERR
        when "browser" then Client::Resource::Browser
        when "file" then Client::Resource::File
        else
          @adapter.write(event: "resource", action: "connect", status: "failure", name: type, type: type, message: "Unknown resource type")
        end

        resource = klass.new(type, @adapter, entitlement: @entitlement)
        resource.connect
        @resources[type] = resource
        @adapter.write(event: "resource", action: "connect", status: "success", name: type, type: type)
      end

      def dispatch(name, action, data)
        resource = @resources[name]
        if resource
          resource.dispatch(action, **data)
        else
          raise "Unknown resource: #{name}"
        end
      end

      def disconnect_resource(name)
        resource = @resources.delete(name)
        resource&.disconnect
        @adapter.write(event: "resource", action: "disconnect", name: name)
      end
    end

    class Handler
      VERSION = "0.1.0".freeze

      include Logging

      def initialize(adapter, arguments: ARGV, program_name: $0, entitlement:)
        @entitlement = entitlement
        @adapter = adapter
        @program_arguments = arguments
        @program_name = program_name
      end

      def connect
        @resources = ResourceMapper.new(adapter: @adapter, entitlement: @entitlement)

        @adapter.write(event: "initialization",
         protocol: { version: VERSION },
         program: {
           name: @program_name,
           arguments: @program_arguments
         })

        loop do
          handle @adapter.recv
        end
      end

      def handle(message)
        case message
        in { event: "resource", action: "connect", name:, type: }
          @resources.connect_resource(type)
        in { event: "resource", action: "command", name:, command:, **data }
          @resources.dispatch(name, command, data)
        in { event: "resource", action: "disconnect", name: }
          @resources.disconnect_resource(name)
        in { event: "exit", status: }
          exit Integer(status)
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

    # Extracted from HTTP. This is so we can
    def self.authority(url)
      if url.port == url.default_port
        url.host
      else
        "#{url.host}:#{url.port}"
      end
    end

    def self.websocket(url:, arguments: ARGV)
      url = URI(url)

      Async do |task|
        endpoint = Async::HTTP::Endpoint.parse(url)

        Async::WebSocket::Client.connect(endpoint) do |adapter|
          transport = Terminalwire::Transport::WebSocket.new(adapter)
          adapter = Terminalwire::Adapter.new(transport)
          entitlement = Entitlement.from_url(url)
          Terminalwire::Client::Handler.new(adapter, arguments:, entitlement:).connect
        end
      end
    end
  end
end
