require "spec_helper"

RSpec.describe Terminalwire::Binary do
  let(:url) { "https://example.com" }
  let(:binary) { described_class.new(url: url) }

  describe "#body" do
    it "returns the correct body" do
      expect(binary.body).to eq <<~BASH
        #{described_class::SHEBANG}
        url: "#{url}"
      BASH
    end
  end

  context "file" do
    let(:path) { File.join(Dir.mktmpdir, "example") }
    before do
      binary.write(path)
    end

    describe "#write" do
      it "writes body to file" do
        expect(File.read(path)).to eq binary.body
      end

      it "is executable" do
        expect(File.executable?(path)).to be true
      end
    end

    describe ".read" do
      let(:opened) { described_class.open path }
      it "reads file" do
        expect(opened.url.to_s).to eq "https://example.com"
      end
    end

    after do
      File.delete(path) if File.exist?(path)
    end
  end

  describe ".write" do
    it "writes binary to file" do
      File.join(Dir.mktmpdir, "executable").tap do |to|
        described_class.write(url:, to:)
        expect(File.read(to)).to eq binary.body
      end
    end
  end
end
