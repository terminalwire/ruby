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
      :storage_path, :terminalwire_home_path

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

      # Initialize the Terminalwire path and storage path
      @terminalwire_home_path = Pathname.new(
        @environment_variable.read("TERMINALWIRE_HOME")
      )
      @storage_path = terminalwire_home_path.join("storage")

      if block_given?
        begin
          yield self
        ensure
          exit
        end
      end
    end

    def exit(status = 0)
      @adapter.write(event: "exit", status: status)
    end

    def close
      @adapter.close
    end
  end
end
