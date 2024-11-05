require "spec_helper"

RSpec.describe Terminalwire::Client::Entitlement::EnvironmentVariables do
  let(:environment_veriables) { described_class.new }
  subject { environment_veriables }

  describe "#permit" do
    let(:variable) { "my-variable" }
    it "adds and upcases variables to the @permitted list" do
      subject.permit(variable)
      expect(subject).to include("my-variable")
    end
  end

  describe "#permitted?" do
    before do
      subject.permit("my-variable")
    end

    it "returns true if the variable matches any permitted variable" do
      expect(subject.permitted?("my-variable")).to be_truthy
    end

    it "returns false if the variable does not match any permitted variable" do
      expect(subject.permitted?("not_my-variable")).to be_falsey
    end
  end
end
