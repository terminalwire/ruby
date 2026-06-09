# frozen_string_literal: true

require "spec_helper"

RSpec.describe Terminalwire::V2::Negotiator do
  Negotiator = Terminalwire::V2::Negotiator

  def negotiate(**overrides)
    Negotiator.negotiate(**{
      client_protocol: 2,
      client_capabilities: %w[stdio file flow],
      server_min: 2,
      server_max: 2,
      server_capabilities: %w[stdio file flow]
    }.merge(overrides))
  end

  describe "protocol version negotiation" do
    it "welcomes when the client's version is in range" do
      result = negotiate(client_protocol: 2, server_min: 2, server_max: 4)
      expect(result[:decision]).to eq("welcome")
      expect(result[:protocol]).to eq(2)
    end

    it "selects min(client, server_max) when the client speaks newer than the server" do
      result = negotiate(client_protocol: 9, server_min: 1, server_max: 4)
      expect(result[:decision]).to eq("welcome")
      expect(result[:protocol]).to eq(4)
    end

    it "selects the client's version when it sits between min and max" do
      result = negotiate(client_protocol: 3, server_min: 1, server_max: 5)
      expect(result[:protocol]).to eq(3)
    end

    it "is incompatible when the client is older than the server's minimum" do
      result = negotiate(client_protocol: 1, server_min: 2, server_max: 4)
      expect(result[:decision]).to eq("incompatible")
      expect(result[:supported]).to eq(min: 2, max: 4)
    end

    it "does not include capabilities on an incompatible result" do
      result = negotiate(client_protocol: 1, server_min: 2, server_max: 2)
      expect(result).not_to have_key(:capabilities)
    end
  end

  describe "capability intersection" do
    it "intersects overlapping capabilities, preserving the client's order" do
      result = negotiate(
        client_capabilities: %w[file stdio browser],
        server_capabilities: %w[stdio file env]
      )
      expect(result[:capabilities]).to eq(%w[file stdio])
    end

    it "returns an empty set when the two sides are disjoint" do
      result = negotiate(
        client_capabilities: %w[browser env],
        server_capabilities: %w[stdio file]
      )
      expect(result[:decision]).to eq("welcome")
      expect(result[:capabilities]).to eq([])
    end

    it "returns an empty set when the client advertises nothing" do
      result = negotiate(client_capabilities: [], server_capabilities: %w[stdio])
      expect(result[:capabilities]).to eq([])
    end

    it "still negotiates capabilities even at the version ceiling" do
      result = negotiate(
        client_protocol: 100, server_min: 1, server_max: 2,
        client_capabilities: %w[stdio], server_capabilities: %w[stdio file]
      )
      expect(result[:protocol]).to eq(2)
      expect(result[:capabilities]).to eq(%w[stdio])
    end
  end
end
