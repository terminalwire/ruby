# frozen_string_literal: true

# Regression: the request host must reach the per-session Thor instance as
# default_url_options[:host], or every server-side URL helper (login,
# `browser open`, license) raises "Missing host to link to!" — which the Handler
# then swallows behind the generic error message. v1 set this on the instance via
# the terminalwire(...) yield block; v2 must too. See Rack#call -> Bridge -> Handler.
#
# This needs the full server runtime, so it requires "terminalwire/v2" (unlike the
# pure-protocol unit specs in spec_helper, which deliberately avoid it).
require "terminalwire/v2"

RSpec.describe Terminalwire::V2::Server::Handler do
  # A stand-in for a Rails Thor CLI: its .terminalwire entrypoint yields the
  # per-session instance, exactly like Server::Thor does.
  def cli_yielding(instance)
    Class.new do
      define_singleton_method(:terminalwire) do |arguments:, context:, &blk|
        blk&.call(instance)
        0
      end
    end
  end

  def url_helpered_instance
    Object.new.tap { |o| o.define_singleton_method(:default_url_options) { @duo ||= {} } }
  end

  it "sets default_url_options[:host] on the Thor instance from the request host" do
    instance = url_helpered_instance
    handler = described_class.new(cli_class: cli_yielding(instance))
    handler.send(:dispatch, Object.new, %w[user login], "terminalwire.com")
    expect(instance.default_url_options[:host]).to eq "terminalwire.com"
  end

  it "leaves url options untouched when there's no host" do
    instance = url_helpered_instance
    handler = described_class.new(cli_class: cli_yielding(instance))
    handler.send(:dispatch, Object.new, [], nil)
    expect(instance.default_url_options).to be_empty
  end

  it "doesn't blow up for a CLI without url helpers" do
    plain = Object.new # no default_url_options
    handler = described_class.new(cli_class: cli_yielding(plain))
    expect { handler.send(:dispatch, Object.new, [], "terminalwire.com") }.not_to raise_error
  end

  it "renders a denied ResponseError as an actionable grant message, not the generic one" do
    warned = []
    ctx = Object.new
    ctx.define_singleton_method(:warn) { |m| warned << m }
    handler = described_class.new(cli_class: cli_yielding(url_helpered_instance))
    denied = Terminalwire::V2::ResponseError.new("denied", "path not permitted: ~/.terminalwire/bin/x")
    expect(handler.send(:handle_error, denied, ctx)).to eq 1
    expect(warned.first).to include("terminalwire-policy")
    expect(warned.first).not_to include("An error occurred")
  end
end
