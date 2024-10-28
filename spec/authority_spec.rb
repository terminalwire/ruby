require "spec_helper"

RSpec.describe Terminalwire::Authority do
  let(:url) { "https://example.com/terminal" }
  let(:authority){ described_class.new(url:) }

  describe "#domain" do
    subject { authority.domain }
    it { is_expected.to eq("example.com") }
  end

  describe "#path" do
    subject { authority.path }
    it { is_expected.to eq("/terminal") }

    context "trailing /" do
      let(:url) { "https://example.com/terminal/" }
      it { is_expected.to eq("/terminal") }
    end

    context "root" do
      let(:url) { "https://example.com" }
      it { is_expected.to eq("/") }
    end

    context "root trailing /" do
      let(:url) { "https://example.com/" }
      it { is_expected.to eq("/") }
    end

    context "root trailing ///" do
      let(:url) { "https://example.com///" }
      it { is_expected.to eq("/") }
    end
  end

  describe "#key" do
    let(:key) { authority.key }
    subject { key }
    it { is_expected.to eq(Base64.urlsafe_encode64("terminalwire://example.com/terminal")) }
  end

  describe "#to_s" do
    subject { authority.to_s }
    it { is_expected.to eq("terminalwire://example.com/terminal") }

    context "anchor" do
      let(:url) { "https://example.com/terminal#anchor" }
      it { is_expected.to eq("terminalwire://example.com/terminal") }
    end

    context "query parameters" do
      let(:url) { "https://example.com/terminal?testing=123" }
      it { is_expected.to eq("terminalwire://example.com/terminal") }
    end

    context "from itself" do
      subject { described_class.new(url: authority.to_s).to_s }
      it { is_expected.to eq("terminalwire://example.com/terminal") }
    end
  end
end
