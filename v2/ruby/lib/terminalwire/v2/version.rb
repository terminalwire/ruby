# frozen_string_literal: true

# Self-contained (full module nesting) so the gemspec can require just this file
# without loading the rest of the library or assuming Terminalwire is defined.
module Terminalwire
  module V2
    VERSION = "2.0.0.alpha1"
  end
end
