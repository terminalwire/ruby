# frozen_string_literal: true

# Regression: the v2 Rails adapter must expose `session` on the v2 shell, and it
# MUST be public. v1's Rails::Thor does `def_delegators :shell, :session`, and
# Ruby 4's Forwardable refuses to forward to a protected/private method (it was a
# warning, now a hard NoMethodError). If `session` slips back under `protected`,
# every session-backed v1 command (current_user, whoami, login) breaks over v2 with
# unchanged Thor code. See terminalwire/v2/rails.rb.
require "terminalwire/v2/rails"

RSpec.describe "v2 Rails shell session parity" do
  subject(:shell) { Terminalwire::V2::Server::Thor::Shell }

  it "defines session on the v2 shell" do
    expect(shell.method_defined?(:session)).to be true
  end

  it "exposes session as PUBLIC (Forwardable can't forward to protected/private)" do
    expect(shell.public_method_defined?(:session)).to be true
    expect(shell.protected_method_defined?(:session)).to be false
    expect(shell.private_method_defined?(:session)).to be false
  end
end
