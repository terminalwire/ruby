require "spec_helper"
require "pathname"
require "uri"
require "rspec"

RSpec.describe Terminalwire::Client::Entitlement::Paths do
  let(:paths) { described_class.new }

  describe "#permit" do
    it "adds a permitted path to the @permitted list" do
      path = "/some/path"
      expanded_path = Pathname.new(path).expand_path

      paths.permit(path)
      expect(paths.map(&:path)).to include(expanded_path)
    end
  end

  describe "#permitted?" do
    before do
      paths.permit("/approved/path/**/*")
    end

    it "returns true if the path matches any permitted path" do
      expect(paths.permitted?("/approved/path/file.txt")).to be_truthy
    end

    it "returns false if the path does not match any permitted path" do
      expect(paths.permitted?("/unapproved/path/file.txt")).to be_falsey
    end
  end
end

RSpec.describe Terminalwire::Client::Entitlement::Schemes do
  let(:schemes) { described_class.new }

  describe "#permit" do
    it "adds a permitted path to the @permitted list" do
      scheme = "http"
      schemes.permit(scheme)
      expect(schemes).to include(scheme)
    end
  end

  describe "#permitted?" do
    before do
      schemes.permit("http")
    end

    it "returns true if the scheme matches any permitted scheme" do
      expect(schemes.permitted?("http://example.com/")).to be_truthy
    end

    it "returns false if the scheme does not match any permitted scheme" do
      expect(schemes.permitted?("file:///secret-password")).to be_falsey
    end
  end
end

RSpec.describe Terminalwire::Client::Entitlement::Policy do
  let(:authority) { "localhost:3000" }
  let(:entitlement) { described_class.new(authority: authority) }

  describe "#initialize" do
    it "sets the authority attribute" do
      expect(entitlement.authority).to eq(authority)
    end

    it "initializes the paths and permits the domain directory" do
      permitted_path = Pathname.new("~/.terminalwire/authorities/#{authority}/storage/junk.txt")
      expect(entitlement.paths.permitted?(permitted_path)).to be_truthy
    end

    it "initializes the paths and permits the domain directory" do
      permitted_path = Pathname.new("~/.terminalwire/authorities/#{authority}/storage")
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

  describe ".from_url" do
    it "creates a new Entitlement object from a URL" do
      url = URI("ws://example.com:8080")
      entitlement_from_url = Terminalwire::Client::Entitlement.from_url(url)
      expect(entitlement_from_url.authority).to eq("example.com:8080")
    end

    it "uses only the host as authority if the port is default" do
      url = URI("wss://example.com")
      entitlement_from_url = Terminalwire::Client::Entitlement.from_url(url)
      expect(entitlement_from_url.authority).to eq("example.com")
    end

    it "uses only the host as authority if the port is default" do
      url = URI("https://example.com")
      entitlement_from_url = Terminalwire::Client::Entitlement.from_url(url)
      expect(entitlement_from_url).to be_a Terminalwire::Client::Entitlement::Policy
    end

    context "terminalwire.com" do
      it "returns RootPolicy" do
        url = URI("https://terminalwire.com")
        expect(Terminalwire::Client::Entitlement.from_url(url)).to be_a Terminalwire::Client::Entitlement::RootPolicy
      end
    end
  end
end

RSpec.describe Terminalwire::Client::Entitlement::RootPolicy do
  let(:authority) { "terminalwire.com" }
  let(:entitlement) { described_class.new }

  describe "#initialize" do
    it "permits paths to authorities directory" do
      permitted_path = Pathname.new("~/.terminalwire/authorities/example.com/storage/junk.txt")
      expect(entitlement.paths.permitted?(permitted_path)).to be_truthy
    end

    it "permits paths to bin directory" do
      permitted_path = Pathname.new("~/.terminalwire/bin/example")
      expect(entitlement.paths.permitted?(permitted_path)).to be_truthy
    end

    it "denies paths to root directory" do
      permitted_path = Pathname.new("/")
      expect(entitlement.paths.permitted?(permitted_path)).to be_falsey
    end
  end

  describe ".from_url" do
    it "returns RootPolicy" do
      url = URI("https://terminalwire.com")
      expect(Terminalwire::Client::Entitlement.from_url(url)).to be_a Terminalwire::Client::Entitlement::RootPolicy
    end
  end
end
