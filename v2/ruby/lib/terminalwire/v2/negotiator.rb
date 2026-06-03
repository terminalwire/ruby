# frozen_string_literal: true

module Terminalwire::V2
  # Pure handshake negotiation: given what the client speaks and what the server
  # supports, decide the agreed protocol version and capability set. This is a
  # function, not a state machine, so it is trivially testable and identical
  # across languages (see conformance/vectors/negotiate).
  module Negotiator
    module_function

    # @return [Hash] either
    #   { decision: "welcome", protocol: Integer, capabilities: Array<String> }
    #   or
    #   { decision: "incompatible", supported: { min:, max: } }
    def negotiate(client_protocol:, client_capabilities:, server_min:, server_max:, server_capabilities:)
      if client_protocol < server_min
        return {
          decision: "incompatible",
          supported: { min: server_min, max: server_max }
        }
      end

      agreed = [client_protocol, server_max].min
      # Intersection, preserving the client's advertised order.
      capabilities = client_capabilities & server_capabilities

      { decision: "welcome", protocol: agreed, capabilities: capabilities }
    end
  end
end
