# frozen_string_literal: true

RSpec.describe Terminalwire do
  it "has a version number" do
    expect(Terminalwire::VERSION).not_to be nil
  end
end

class TestAdapter
  attr_reader :responses

  def initialize
    @responses = []
  end

  def write(**data)
    @responses << data
  end

  def response
    @responses.pop
  end
end

RSpec.describe Terminalwire::Client::Resource::File do
  let(:adapter) { TestAdapter.new }
  let(:file) { Terminalwire::Client::Resource::File.new("file", adapter) }
  let(:response) { adapter.response }
  subject { response }

  describe "#mkdir" do
    context "unauthorized access" do
      before{ file.dispatch("mkdir", path: "/usr/bin/danger") }
      it { is_expected.to include(
        event: "device",
        response: "Access to /usr/bin/danger is not allowed by client",
        status: "failure",
        name: "file")
      }
    end

    context "authorized access" do
      before{ file.dispatch("mkdir", path: "~/.terminalwire/junks") }
      it { is_expected.to include(
        event: "device",
        status: "success",
        name: "file")
      }
    end
  end
end
