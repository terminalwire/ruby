require "fileutils"
require "io/console"


module Terminalwire::Client::Resource
  # Dispatches messages from the Client::Handler to the appropriate resource.
  class Handler
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
      in { event:, action: "command", name:, command:, parameters: }
        resource = @resources.fetch(name)
        resource.command(command, **parameters)
      in { event:, action: "notify", name:, command:, parameters: }
        resource = @resources.fetch(name)
        resource.notify(command, **parameters)
      end
    end
  end

  # Dispatcher, security, and response macros for resources.
  class Base < Terminalwire::Resource::Base
    def initialize(*, entitlement:, **)
      super(*, **)
      @entitlement = entitlement
      connect
    end

    def command(command, **parameters)
      begin
        if permit(command, **parameters)
          succeed self.public_send(command, **parameters)
        else
          fail "Client denied #{command}", command:, parameters:
        end
      rescue => e
        fail e.message, command:, parameters:
        raise
      end
    end

    def notify(command, **parameters)
      begin
        if permit(command, **parameters)
          self.public_send(command, **parameters)
        end
      rescue => e
        # Ignore errors on notifications to avoid affecting the reactor
      end
    end

    protected

    def permit(...)
      false
    end
  end

  class EnvironmentVariable < Base
    # Accepts a list of environment variables to permit.
    def read(name:)
      ENV[name]
    end

    # def write(name:, value:)
    #   ENV[name] = value
    # end

    protected

    def permit(command, name:, **)
      @entitlement.environment_variables.permitted? name
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

    protected

    def permit(...)
      true
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

    protected

    def permit(...)
      true
    end
  end

  class File < Base
    File = ::File

    def read(path:)
      File.read File.expand_path(path)
    end

    def write(path:, content:, mode: nil)
      File.open(File.expand_path(path), "w", mode) { |f| f.write(content) }
    end

    def append(path:, content:, mode: nil)
      File.open(File.expand_path(path), "a", mode) { |f| f.write(content) }
    end

    def delete(path:)
      File.delete File.expand_path(path)
    end

    def exist(path:)
      File.exist? File.expand_path(path)
    end

    def change_mode(path:, mode:)
      File.chmod mode, File.expand_path(path)
    end

    protected

    def permit(command, path:, mode: nil, **)
      @entitlement.paths.permitted? path, mode:
    end
  end

  class Directory < Base
    File = ::File

    def list(path:)
      Dir.glob path
    end

    def create(path:)
      FileUtils.mkdir_p File.expand_path(path)
    rescue Errno::EEXIST
      # Do nothing
    end

    def exist(path:)
      Dir.exist? path
    end

    def delete(path:)
      Dir.delete path
    end

    protected

    def permit(command, path:, **)
      @entitlement.paths.permitted? path
    end
  end

  class Browser < Base
    def launch(url:)
      Launchy.open(URI(url))
      # TODO: This is a hack to get the `respond` method to work.
      # Maybe explicitly call a `suceed` and `fail` method?
      nil
    end

    protected

    def permit(command, url:, **)
      @entitlement.schemes.permitted? url
    end
  end
end
