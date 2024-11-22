module Terminalwire::Client::Entitlement
  # ENV vars that the server can access on the client.
  class EnvironmentVariables
    include Enumerable

    def initialize
      @permitted = Set.new
    end

    def each(&)
      @permitted.each(&)
    end

    def permit(variable)
      @permitted << variable.to_s
    end

    def permitted?(key)
      include? key.to_s
    end

    def serialize
      map { |name| { name: } }
    end
  end
end
