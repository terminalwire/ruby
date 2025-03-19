require "fileutils"

module Terminalwire::Server
  # Contains all of the resources that are accessible to the server on the client-side.
  # It's the primary interface for the server to interact with the client and is integrated
  # into other libraries like Thor, etc.
  class Context
    extend Forwardable

    attr_reader \
      :stdout, :stdin, :stderr,
      :browser,
      :file, :directory,
      :environment_variable,
      :authority,
      :root_path,
      :authority_path,
      :storage_path

    def_delegators :@stdout, :puts, :print
    def_delegators :@stdin, :gets, :getpass

    def initialize(adapter:, entitlement:)
      @adapter = adapter
      @entitlement = entitlement

      # Initialize resources
      @stdout = Resource::STDOUT.new("stdout", @adapter)
      @stdin = Resource::STDIN.new("stdin", @adapter)
      @stderr = Resource::STDERR.new("stderr", @adapter)
      @browser = Resource::Browser.new("browser", @adapter)
      @file = Resource::File.new("file", @adapter)
      @directory = Resource::Directory.new("directory", @adapter)
      @environment_variable = Resource::EnvironmentVariable.new("environment_variable", @adapter)

      # Authority is provided by the client.
      @authority = @entitlement.fetch(:authority)
      # The Terminalwire home path is provided by the client and set
      # as an environment variable.
      @root_path = Pathname.new(
        @environment_variable.read("TERMINALWIRE_HOME")
      )
      # Now derive the rest of the paths from the Terminalwire home path.
      @authority_path = @root_path.join("authorities", @authority)
      @storage_path = @authority_path.join("storage")

      if block_given?
        begin
          yield self
        ensure
          exit
        end
      end
    end

    # Wraps the environment variables in a hash-like object that can be accessed
    # from client#ENV. This makes it look and feel just like the ENV object in Ruby.
    class Env
      def initialize(context:)
        @context = context
      end

      def [](name)
        @context.environment_variable.read(name)
      end
    end

    def ENV
      @ENV ||= Env.new(context: self)
    end

    def exit(status = 0)
      @adapter.write(event: "exit", status: status)
    ensure
      close
    end

    def close
      @adapter.close
    end
  end
end
