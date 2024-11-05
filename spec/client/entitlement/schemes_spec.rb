require "spec_helper"

RSpec.describe Terminalwire::Client::Entitlement::Schemes do
  let(:schemes) { described_class.new }

  describe "#permit" do
    it "adds a permitted path to the @permitted list" do
      scheme = "http"
      schemes.permit(scheme)
      expect(schemes).to include(scheme)
    end
  end

  describe "#permitted?" do
    before do
      schemes.permit("http")
    end

    it "returns true if the scheme matches any permitted scheme" do
      expect(schemes.permitted?("http://example.com/")).to be_truthy
    end

    it "returns false if the scheme does not match any permitted scheme" do
      expect(schemes.permitted?("file:///secret-password")).to be_falsey
    end
  end
end
