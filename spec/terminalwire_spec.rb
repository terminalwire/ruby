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
  let(:entitlement) { Terminalwire::Client::Entitlement.new(authority: "test") }
  let(:file) { Terminalwire::Client::Resource::File.new("file", adapter, entitlement:) }
  let(:response) { adapter.response }
  subject { response }

  describe "#mkdir" do
    context "unauthorized access" do
      before{ file.dispatch("mkdir", path: "/usr/bin/danger") }
      it { is_expected.to include(
        event: "resource",
        response: "Access to /usr/bin/danger denied",
        status: "failure",
        name: "file")
      }
    end

    context "authorized access" do
      before{ file.dispatch("mkdir", path: "~/.terminalwire/authorities/test/files/howdy") }
      it { is_expected.to include(
        event: "resource",
        status: "success",
        name: "file")
      }
    end
  end
end

RSpec.describe Terminalwire::Client::Resource::Browser do
  let(:adapter) { TestAdapter.new }
  let(:entitlement) { Terminalwire::Client::Entitlement.new(authority: "test") }
  let(:browser) { Terminalwire::Client::Resource::Browser.new("browser", adapter, entitlement:) }
  let(:response) { adapter.response }
  subject { response }

  describe "#launch" do
    context "unauthorized scheme" do
      before{ browser.dispatch("launch", url: "file:///usr/bin/env") }
      it { is_expected.to include(
        event: "resource",
        response: "Access to file:///usr/bin/env denied",
        status: "failure",
        name: "browser")
      }
    end

    context "authorized scheme" do
      # Intercept the call that actually launches the browser window.
      before { expect(Launchy).to receive(:open).once }
      before{ browser.dispatch("launch", url: "http://example.com") }
      it { is_expected.to include(
        event: "resource",
        status: "success",
        name: "browser")
      }
    end
  end
end
