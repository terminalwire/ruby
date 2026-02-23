module Terminalwire::Client::Entitlement
  # Shell commands the server can execute on the client.
  # Commands are permitted by prefix matching, e.g. "git status" permits
  # "git status", "git status --short", etc.
  class Shell
    include Enumerable

    # Default timeout in seconds
    DEFAULT_TIMEOUT = 30
    # Maximum timeout in seconds (5 minutes)
    MAX_TIMEOUT = 300
    # Maximum output size in bytes (10MB)
    MAX_OUTPUT_SIZE = 10 * 1024 * 1024

    def initialize
      @permitted = Set.new
    end

    def each(&)
      @permitted.each(&)
    end

    # Permit a command prefix, e.g. "git status", "bundle exec"
    def permit(command_prefix)
      @permitted << command_prefix.to_s
    end

    # Check if a command with args is permitted.
    # Builds the full command string and checks if it starts with any permitted prefix.
    def permitted?(command, args = [])
      full_command = [command, *args].join(" ")
      @permitted.any? { |prefix| full_command.start_with?(prefix) }
    end

    def serialize
      map { |command| { command: } }
    end
  end
end
