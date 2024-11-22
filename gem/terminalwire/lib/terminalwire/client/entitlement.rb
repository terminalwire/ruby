require "pathname"

module Terminalwire::Client
  # Entitlements are the security boundary between the server and the client that lives on the client.
  # The server might request a file or directory from the client, and the client will check the entitlements
  # to see if the server is authorized to access the requested resource.
  module Entitlement
  end
end
