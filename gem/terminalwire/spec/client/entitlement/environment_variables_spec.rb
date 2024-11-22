require "spec_helper"

RSpec.describe Terminalwire::Client::Entitlement::EnvironmentVariables do
  let(:environment_veriables) { described_class.new }
  let(:variable) { "my-variable" }
  before { subject.permit(variable) }
  subject { environment_veriables }

  describe "#permit" do
    it "adds and upcases variables to the @permitted list" do
      expect(subject).to include(variable)
    end
  end

  describe "#permitted?" do
    it "returns true if the variable matches any permitted variable" do
      expect(subject.permitted?("my-variable")).to be_truthy
    end

    it "returns false if the variable does not match any permitted variable" do
      expect(subject.permitted?("not_my-variable")).to be_falsey
    end
  end

  describe "#serialize" do
    it "returns an array of serialized variables" do
      expect(subject.serialize).to eq([
        { name: "my-variable" }
      ])
    end
  end
end
