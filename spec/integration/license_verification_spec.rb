require "spec_helper"

RSpec.describe "Terminalwire license verification", type: :system do
  around do |example|
    Async do
      example.run
    end
  end

  let(:service_license_verification) {
    Terminalwire::Client::ServerLicenseVerification.new(url:)
  }

  context "licensed server" do
    let(:url) { "https://tinyzap.com/terminal" }
    subject { service_license_verification.message }
    it { is_expected.to be_nil }
  end

  context "unlicensed server" do
    let(:url) { "https://tinyzap.com/unlicensed-terminal" }
    subject { service_license_verification.message }
    it { is_expected.to eql "Can't find a valid server license for https://tinyzap.com/unlicensed-terminal.\n" }
  end
end
