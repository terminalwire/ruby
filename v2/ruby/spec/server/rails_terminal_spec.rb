# frozen_string_literal: true

require "spec_helper"
require "terminalwire/v2/rails"

RSpec.describe Terminalwire::V2::Rails do
  describe Terminalwire::V2::Rails::VersionEndpoint do
    let(:v2) { ->(env) { [:v2, env] } }
    let(:v3) { ->(env) { [:v3, env] } }

    subject(:endpoint) do
      described_class.new(default: v2, by_subprotocol: { "terminalwire.v2" => v2, "terminalwire.v3" => v3 })
    end

    def env(protocols)
      { "HTTP_SEC_WEBSOCKET_PROTOCOL" => protocols }
    end

    it "routes an advertised version subprotocol to its handler" do
      expect(endpoint.call(env("terminalwire.v2")).first).to eq :v2
      expect(endpoint.call(env("terminalwire.v3")).first).to eq :v3
    end

    it "defaults (to v2) when no known version is advertised" do
      expect(endpoint.call(env(nil)).first).to eq :v2
      expect(endpoint.call(env("")).first).to eq :v2
      expect(endpoint.call(env("ws, made-up")).first).to eq :v2
    end

    it "picks the first matching version among several offered" do
      expect(endpoint.call(env("ws, terminalwire.v3")).first).to eq :v3
    end
  end

  describe ".terminal" do
    let(:cli) { Class.new(Thor) }

    it "returns a v2-default VersionEndpoint" do
      expect(described_class.terminal(cli)).to be_a(Terminalwire::V2::Rails::VersionEndpoint)
    end

    it "routes the v2 subprotocol — and anything unversioned — to a Server::Rack" do
      endpoint = described_class.terminal(cli)
      rack = endpoint.instance_variable_get(:@default)
      expect(rack).to be_a(Terminalwire::V2::Server::Rack)
      # the v2 subprotocol maps to the same Rack as the default
      expect(endpoint.instance_variable_get(:@by_subprotocol)["terminalwire.v2"]).to be(rack)
    end

    it "dualizes the cli so it answers the v2 wire" do
      described_class.terminal(cli)
      expect(cli.include?(Terminalwire::V2::Server::DualThor)).to be(true)
    end
  end
end
