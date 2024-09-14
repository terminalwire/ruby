module Terminalwire
  module Client
    module Resource
      class Base < Terminalwire::Resource::Base
        def initialize(*, entitlement:, **)
          super(*, **)
          @entitlement = entitlement
          connect
        end

        def dispatch(command:, **data)
          respond self.public_send(command, **data)
        end

        def deconstruct_keys(keys)
          { event: "resource", action: "command", name: @name }
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

        # Ensure the default file mode is read/write for owner only. This ensures
        # that if the server tries uploading an executable file, it won't be when it
        # lands on the client.
        #
        # Eventually we'll move this into entitlements so the client can set maximum
        # permissions for files and directories.
        FILE_PERMISSIONS = 0o600 # rw-------

        def read(path:)
          File.read File.expand_path(path)
        end

        def write(path:, content:)
          File.open(File.expand_path(path), "w", FILE_PERMISSIONS) { |f| f.write(content) }
        end

        def append(path:, content:)
          File.open(File.expand_path(path), "a", FILE_PERMISSIONS) { |f| f.write(content) }
        end

        def mkdir(path:)
          FileUtils.mkdir_p(File.expand_path(path))
        end

        def exist(path:)
          File.exist? File.expand_path(path)
        end

        def dispatch(path:, **data)
          if @entitlement.paths.permitted? path
            super(path: File.expand_path(path), **data)
          else
            respond("Access to #{path} denied", status: "failure")
          end
        end
      end

      class Browser < Base
        def dispatch(url:, **data)
          if @entitlement.schemes.permitted? url
            super(url:, **data)
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

    class ResourceHandler
      include Enumerable

      def initialize
        @resources = {}
        yield self if block_given?
      end

      def each(&block)
        @resources.values.each(&block)
      end

      def add(resource)
        # Detect if the resource is already registered and throw an error
        if @resources.key?(resource.name)
          raise "Resource #{resource.name} already registered"
        else
          @resources[resource.name] = resource
        end
      end
      alias :<< :add

      def dispatch(**message)
        case message
        in { event:, action:, name:, **data }
          resource = @resources.fetch(name)
          resource.dispatch(**data)
        end
      end
    end

    class Handler
      VERSION = "0.1.0".freeze

      include Logging

      attr_reader :adapter, :entitlement, :resources

      def initialize(adapter, arguments: ARGV, program_name: $0, entitlement:)
        @entitlement = entitlement
        @adapter = adapter
        @program_arguments = arguments
        @program_name = program_name

        @resources = ResourceHandler.new do |it|
          it << Resource::STDOUT.new("stdout", @adapter, entitlement:)
          it << Resource::STDIN.new("stdin", @adapter, entitlement:)
          it << Resource::STDERR.new("stderr", @adapter, entitlement:)
          it << Resource::Browser.new("browser", @adapter, entitlement:)
          it << Resource::File.new("file", @adapter, entitlement:)
        end
      end

      def connect
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
        in { event: "resource", action: "command", name: }
          @resources.dispatch(**message)
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
