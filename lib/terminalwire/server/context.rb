module Terminalwire::Server
  class Context
    extend Forwardable

    attr_reader :stdout, :stdin, :stderr, :browser, :file, :directory, :storage_path

    def_delegators :@stdout, :puts, :print
    def_delegators :@stdin, :gets, :getpass

    def initialize(adapter:, entitlement:)
      @adapter = adapter

      # TODO: Encapsulate entitlement in a class instead of a hash.
      @entitlement = entitlement
      @storage_path = Pathname.new(entitlement.fetch(:storage_path))

      @stdout = Resource::STDOUT.new("stdout", @adapter)
      @stdin = Resource::STDIN.new("stdin", @adapter)
      @stderr = Resource::STDERR.new("stderr", @adapter)
      @browser = Resource::Browser.new("browser", @adapter)
      @file = Resource::File.new("file", @adapter)
      @directory = Resource::Directory.new("directory", @adapter)

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
