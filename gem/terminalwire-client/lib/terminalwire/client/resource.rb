require "fileutils"
require "io/console"
require "open3"

module Terminalwire::Client::Resource
  # Dispatches messages from the Client::Handler to the appropriate resource.
  class Handler
    include Enumerable

    def initialize(adapter:, entitlement:)
      @adapter = adapter
      @entitlement = entitlement
      @resources = {}
      
      # Register default resources
      self << STDOUT
      self << STDIN
      self << STDERR
      self << Browser
      self << File
      self << Directory
      self << EnvironmentVariable
      self << Shell
      
      yield self if block_given?
    end

    def each(&block)
      @resources.values.each(&block)
    end

    def add(resource_class)
      # Get the resource name from its key
      resource_name = resource_class.key
      
      # Instantiate the resource with proper parameters
      resource = resource_class.new(resource_name, @adapter, entitlement: @entitlement)
      
      # Detect if the resource is already registered and throw an error
      if @resources.key?(resource_name)
        raise "Resource #{resource_name} already registered"
      else
        @resources[resource_name] = resource
      end
    end
    alias :<< :add

    def dispatch(**message)
      case message
      in { event:, action:, name:, command:, parameters: }
        resource = @resources.fetch(name)
        resource.command(command, **parameters)
      end
    end
  end

  # Dispatcher, security, and response macros for resources.
  class Base < Terminalwire::Resource::Base
    def initialize(name = nil, adapter = nil, entitlement: nil)
      # Use class key as default name if not provided
      name ||= self.class.key if self.class.respond_to?(:key)
      super(name, adapter)
      @entitlement = entitlement
      connect if entitlement # Only connect if entitlement is provided
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

    protected

    def permit(...)
      false
    end
  end

  class EnvironmentVariable < Base
    def self.key
      "environment_variable"
    end

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
    def self.key
      "stdout"
    end

    def connect
      @io = $stdout
    end

    def print(data:)
      @io.print(data)
      @io.flush
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
    def self.key
      "stderr"
    end

    def connect
      @io = $stderr
    end
  end

  class STDIN < Base
    def self.key
      "stdin"
    end

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
    def self.key
      "file"
    end

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
    def self.key
      "directory"
    end

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
    def self.key
      "browser"
    end

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

  class Shell < Base
    def self.key
      "shell"
    end

    # Execute a command with arguments using array-based execution (no shell interpretation).
    # Returns a hash with stdout, stderr, exitstatus, and success.
    def run(command:, args: [], timeout: nil, chdir: nil)
      # Apply timeout limits
      timeout = resolve_timeout(timeout)

      # Build execution options
      options = {}
      options[:chdir] = ::File.expand_path(chdir) if chdir

      # Execute command with array form (safe - no shell interpretation)
      stdout, stderr, status = execute_with_timeout(command, args, timeout, options)

      # Truncate output if too large
      stdout = truncate_output(stdout)
      stderr = truncate_output(stderr)

      {
        stdout: stdout,
        stderr: stderr,
        exitstatus: status.exitstatus,
        success: status.success?
      }
    end

    protected

    def permit(command_name, command:, args: [], chdir: nil, **)
      # Check if command + args prefix is permitted
      return false unless @entitlement.shell.permitted?(command, args)

      # If chdir specified, it must be a permitted path
      if chdir
        return false unless @entitlement.paths.permitted?(chdir)
      end

      true
    end

    private

    def resolve_timeout(timeout)
      max_timeout = Terminalwire::Client::Entitlement::Shell::MAX_TIMEOUT
      default_timeout = Terminalwire::Client::Entitlement::Shell::DEFAULT_TIMEOUT

      if timeout.nil?
        default_timeout
      else
        [timeout.to_i, max_timeout].min
      end
    end

    def execute_with_timeout(command, args, timeout, options)
      Timeout.timeout(timeout) do
        Open3.capture3(command, *args, **options)
      end
    rescue Timeout::Error
      ["", "Command timed out after #{timeout} seconds", OpenStruct.new(exitstatus: 124, success?: false)]
    end

    def truncate_output(output)
      max_size = Terminalwire::Client::Entitlement::Shell::MAX_OUTPUT_SIZE
      if output.bytesize > max_size
        output.byteslice(0, max_size) + "\n... (output truncated)"
      else
        output
      end
    end
  end
end
