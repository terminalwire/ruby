require "spec_helper"

RSpec.describe Terminalwire::Client::Entitlement::Policy::Base do
  let(:authority) { "localhost:3000" }
  let(:entitlement) { described_class.new(authority: authority) }

  describe "#initialize" do
    it "sets the authority attribute" do
      expect(entitlement.authority).to eq(authority)
    end

    it "initializes the paths and permits the domain directory" do
      permitted_path = Terminalwire::Client.root_path.join("authorities/#{authority}/storage/junk.txt")
      expect(entitlement.paths.permitted?(permitted_path)).to be_truthy
    end

    it "initializes the paths and permits the domain directory" do
      permitted_path = Terminalwire::Client.root_path.join("authorities/#{authority}/storage")
      expect(entitlement.paths.permitted?(permitted_path)).to be_truthy
    end

    it "initializes the paths and permits the http scheme" do
      permitted_url = "http://#{authority}"
      expect(entitlement.schemes.permitted?(permitted_url)).to be_truthy
    end

    it "initializes the paths and permits the https scheme" do
      permitted_url = "https://#{authority}"
      expect(entitlement.schemes.permitted?(permitted_url)).to be_truthy
    end
  end

  describe "#serialize" do
    it "returns a hash with the authority" do
      expect(entitlement.serialize).to eq(
        authority: "localhost:3000",
        schemes: [
          { scheme: "http" },
          { scheme: "https"}
        ],
        paths: [
          {
            location: "~/.terminalwire/authorities/localhost:3000/storage",
            mode: 384
          },
          {
            location: "~/.terminalwire/authorities/localhost:3000/storage/**/*",
            mode: 384
          }
        ],
        environment_variables: [
          { name: "TERMINALWIRE_HOME" }
        ]
      )
    end
  end

  describe ".resolve" do
    let(:authority) { "example.com:8080" }

    it "creates a new Entitlement object from a URL" do
      entitlement_resolve = Terminalwire::Client::Entitlement::Policy.resolve(authority:)
      expect(entitlement_resolve.authority).to eq("example.com:8080")
    end

    context "terminalwire.com" do
      let(:authority) { "terminalwire.com" }
      let(:entitlement) { Terminalwire::Client::Entitlement::Policy.resolve(authority:) }
      it "returns Policy::Root" do
        expect(entitlement).to be_a Terminalwire::Client::Entitlement::Policy::Root
      end
      describe "~/.terminalwire/bin" do
        it "has access to directory" do
          expect(entitlement.paths.permitted?(Terminalwire::Client.root_path.join("bin"))).to be_truthy
        end
        it "has change mode to executable permit" do
          expect(entitlement.paths.permitted?(Terminalwire::Client.root_path.join("bin/my-app"), mode: 0o755)).to be_truthy
        end
      end
    end
  end
end

RSpec.describe Terminalwire::Client::Entitlement::Policy::Root do
  let(:authority) { "terminalwire.com" }
  let(:entitlement) { described_class.new }

  describe "#initialize" do
    it "permits paths to authorities directory" do
      permitted_path = Terminalwire::Client.root_path.join("authorities/example.com/storage/junk.txt")
      expect(entitlement.paths.permitted?(permitted_path)).to be_truthy
    end

    it "permits paths to bin directory" do
      permitted_path = Terminalwire::Client.root_path.join("bin/example")
      expect(entitlement.paths.permitted?(permitted_path)).to be_truthy
    end

    it "denies paths to root directory" do
      permitted_path = Pathname.new("/")
      expect(entitlement.paths.permitted?(permitted_path)).to be_falsey
    end
  end

  describe ".resolve" do
    it "returns Policy::Root" do
      url = URI("https://terminalwire.com")
      expect(Terminalwire::Client::Entitlement::Policy.resolve(authority:)).to be_a Terminalwire::Client::Entitlement::Policy::Root
    end
  end
end
