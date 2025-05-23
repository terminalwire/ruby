require "spec_helper"
require "tmpdir"

RSpec.describe Terminalwire::Client::Resource::File do
  let(:adapter) { Terminalwire::Adapter::Test.new }
  let(:entitlement) { Terminalwire::Client::Entitlement::Policy::Base.new(authority: "test") }
  let(:file) { Terminalwire::Client::Resource::File.new("file", adapter, entitlement:) }
  let(:response) { adapter.response }
  subject { response }
  before { FileUtils.mkdir_p(entitlement.storage_path) }
  after { FileUtils.rm_rf(entitlement.storage_path) }

  around do |example|
    original = ENV["TERMINALWIRE_HOME"]
    ENV["TERMINALWIRE_HOME"] = Dir.mktmpdir

    example.run

    ENV["TERMINALWIRE_HOME"] = original
  end

  describe "#write" do
    context "unpermitted path" do
      before{ file.command("write", path: "/usr/bin/howdy.txt") }
      it { is_expected.to include(
        event: "resource",
        response: "Client denied write",
        status: "failure",
        name: "file",
        command: "write",
        parameters: {
          path: "/usr/bin/howdy.txt"
        })
      }
    end

    context "permitted path" do
      describe "permitted implicit mode" do
        before {
          file.command(
            "write",
            path: Terminalwire::Client.root_path.join("authorities/test/storage/howdy.txt").to_s,
            content: ""
          )
        }
        it {
          is_expected.to include(
          event: "resource",
          status: "success",
          name: "file")
        }
      end

      describe "permitted explicit mode" do
        before {
          file.command(
            "write",
            path: Terminalwire::Client.root_path.join("authorities/test/storage/howdy.txt").to_s,
            content: "",
            mode: 0o500
          )
        }
        it { is_expected.to include(
          event: "resource",
          status: "success",
          name: "file")
        }
      end

      describe "unpermitted explicit mode" do
        before {
          file.command(
            "write",
            path: Terminalwire::Client.root_path.join("authorities/test/storage/howdy.txt").to_s,
            content: "",
            mode: 0o700
          )
        }

        it { is_expected.to include(
          event: "resource",
          response: "Client denied write",
          status: "failure",
          name: "file",
          command: "write",
          parameters: {
            path: Terminalwire::Client.root_path.join("authorities/test/storage/howdy.txt").to_s,
            mode: 0o700,
            content: ""
          })
        }
      end
    end
  end

  describe "#change_mode" do
    let(:path) { Terminalwire::Client.root_path.join("authorities/test/storage/howdy.txt").to_s }
    before { file.command("write", path:, content: "") }
    before { file.command("change_mode", path:, mode:) }

    context "permitted_mode" do
      let(:mode) { 0o500 }
      it { is_expected.to include(
        event: "resource",
        status: "success",
        name: "file")
      }
    end
    context "unpermitted mode" do
      let(:mode) { 0o700 }
      it { is_expected.to include(
        command: "change_mode",
        event: "resource",
        name: "file",
        status: "success",
        parameters: {
          mode: 448,
          path: Terminalwire::Client.root_path.join("authorities/test/storage/howdy.txt").to_s
        },
        response: "Client denied change_mode",
        status: "failure")
      }
    end
  end
end

RSpec.describe Terminalwire::Client::Resource::Directory do
  let(:adapter) { Terminalwire::Adapter::Test.new }
  let(:entitlement) { Terminalwire::Client::Entitlement::Policy::Base.new(authority: "test") }
  let(:directory) { Terminalwire::Client::Resource::Directory.new("directory", adapter, entitlement:) }
  let(:response) { adapter.response }
  before { FileUtils.mkdir_p(entitlement.storage_path) }
  after { FileUtils.rm_rf(entitlement.storage_path) }
  subject { response }

  describe "#create" do
    context "unpermitted access" do
      before{ directory.command("create", path: "/usr/bin/howdy") }
      it { is_expected.to include(
        event: "resource",
        response: "Client denied create",
        status: "failure",
        name: "directory",
        command: "create",
        parameters: {
          path: "/usr/bin/howdy"
        })
      }
    end

    context "permitted access" do
      before{
        directory.command("create",
          path: Terminalwire::Client.root_path.join("authorities/test/storage/howdy").to_s
        )
      }
      it { is_expected.to include(
        event: "resource",
        status: "success",
        name: "directory")
      }
    end
  end
end

RSpec.describe Terminalwire::Client::Resource::Browser do
  let(:adapter) { Terminalwire::Adapter::Test.new }
  let(:entitlement) { Terminalwire::Client::Entitlement::Policy::Base.new(authority: "test") }
  let(:browser) { Terminalwire::Client::Resource::Browser.new("browser", adapter, entitlement:) }
  let(:response) { adapter.response }
  subject { response }

  describe "#launch" do
    context "unpermitted scheme" do
      before{ browser.command("launch", url: "file:///usr/bin/env") }
      it { is_expected.to include(
        event: "resource",
        response: "Client denied launch",
        status: "failure",
        name: "browser",
        command: "launch",
        parameters: {
          url: "file:///usr/bin/env"
        })
      }
    end

    context "permitted scheme" do
      # Intercept the call that actually launches the browser window.
      before { expect(Launchy).to receive(:open).once }
      before{ browser.command("launch", url: "http://example.com") }
      it { is_expected.to include(
        event: "resource",
        status: "success",
        name: "browser")
      }
    end
  end
end
