# frozen_string_literal: true

RSpec.describe Terminalwire do
  it "has a version number" do
    expect(Terminalwire::VERSION).not_to be nil
  end
end


RSpec.describe Terminalwire::Client::Resource::File do
  let(:adapter) { Object.new }
  let(:file) { Terminalwire::Client::Resource::File.new("file", adapter) }
  describe "#read" do
    it "reads file" do
      expect(file.read(path: __FILE__)).to eql(File.read(__FILE__))
    end
  end
end
