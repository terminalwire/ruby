
# frozen_string_literal: true

require "spec_helper"

RSpec.describe Terminalwire::Licensing do
  let(:private_key){ Terminalwire::Licensing.generate_private_key }
  let(:public_key){ private_key.public_key }
  let(:license_url) { "https://example.com/license/1" }
  let(:server_key){
    Terminalwire::Licensing::Issuer::ServerKeyGenerator.new(public_key:, license_url:).server_key
  }
  let(:client_key_generator) { Terminalwire::Licensing::Server::ClientKeyGenerator.new(server_key:) }
  let(:client_key) { client_key_generator.client_key }
  let(:client_key_verifier) { Terminalwire::Licensing::Issuer::ClientKeyVerifier.new(client_key:, private_key:) }
  let(:server_attestation) { client_key_verifier.server_attestation }

  describe Terminalwire::Licensing::Issuer::ServerKeyGenerator do
    describe "#server_key" do
      subject { server_key }
      it { is_expected.to be_a(String) }
      it { is_expected.to match(/server_key_(\w+)/) }
    end

    describe ".deseralize" do
      subject { described_class.deserialize server_key }
      it "has keys" do
        expect(subject.keys).to eql(%w[
          version
          generated_at
          public_key
          license_url
        ])
      end
      it "has license_url" do
        expect(subject.fetch("license_url")).to eql("https://example.com/license/1")
      end
      it "has version" do
        expect(subject.fetch("version")).to eql("1.0")
      end
      it "has public_key" do
        expect(subject.fetch("public_key")).to match(/\w+/)
      end
    end
  end

  describe Terminalwire::Licensing::Server::ClientKeyGenerator do
    describe "client_key" do
      subject { client_key }
      it { is_expected.to be_a(String) }
      it { is_expected.to match(/client_key_(\w+)/) }
    end

    describe ".deseralize" do
      subject { described_class.deserialize client_key }
      it "has keys" do
        expect(subject.keys).to eql(%w[
          version
          license_url
          server_attestation
        ])
      end
      it "has license_url" do
        expect(subject.fetch("license_url")).to eql("https://example.com/license/1")
      end
      it "has version" do
        expect(subject.fetch("version")).to eql("1.0")
      end
      it "has server_attestation" do
        expect(subject.fetch("server_attestation")).to match(/\w+/)
      end
    end
  end

  describe Terminalwire::Licensing::Issuer::ClientKeyVerifier do
    it "is valid" do
      expect(client_key_verifier).to be_valid
    end

    it "has version key" do
      expect(server_attestation.keys).to include("version")
    end

    it "has generated_at key" do
      expect(server_attestation.keys).to include("generated_at")
    end
  end
end
