module Terminalwire::Client::Entitlement
  # URLs the server can open on the client.
  class Schemes
    include Enumerable

    def initialize
      @permitted = Set.new
    end

    def each(&)
      @permitted.each(&)
    end

    def permit(scheme)
      @permitted << scheme.to_s
    end

    def permitted?(url)
      include? URI(url).scheme
    end

    def serialize
      @permitted.to_a.map(&:to_s)
    end
  end
end
