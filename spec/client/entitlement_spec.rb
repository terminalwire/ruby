require "spec_helper"
require "pathname"
require "uri"
require "rspec"

RSpec.describe Terminalwire::Client::Entitlement::Paths::Permit do
  let(:permit) { described_class.new(path:) }
  let(:path) { "/some/path" }
  describe "#permitted_path?" do
    it "permits /some/path" do
      expect(permit.permitted_path?("/some/path")).to be_truthy
    end
    it "does not permit /some/path/far/far/away" do
      expect(permit.permitted_path?("/some/path/far/far/away")).to be_falsey
    end
    it "does not permit /another/path" do
      expect(permit.permitted_path?("/another/path")).to be_falsey
    end
  end
  describe "#permitted_mode?" do
    context "default MODE = '0o600'" do
      it "permits 0o600" do
        expect(permit.permitted_mode?(0o600)).to be_truthy
      end
      it "permits 0o500" do
        expect(permit.permitted_mode?(0o500)).to be_truthy
      end
      it "does not permit 0o700" do
        expect(permit.permitted_mode?(0o700)).to be_falsey
      end
      it "does not permit 0o601" do
        expect(permit.permitted_mode?(0o601)).to be_falsey
      end
      it "does not permit 0o610" do
        expect(permit.permitted_mode?(0o610)).to be_falsey
      end
      it "does not permit 0o501" do
        expect(permit.permitted_mode?(0o501)).to be_falsey
      end
    end
    context "mode: 0o700" do
      let(:permit) { described_class.new(path:, mode: 0o700) }
      it "permits 0o700" do
        expect(permit.permitted_mode?(0o700)).to be_truthy
      end
      it "permits 0o600" do
        expect(permit.permitted_mode?(0o600)).to be_truthy
      end
      it "does not permit 0o701" do
        expect(permit.permitted_mode?(0o701)).to be_falsey
      end
    end
    context "mode: 0o005" do
      let(:permit) { described_class.new(path:, mode: 0o005) }
      it "permits 0o005" do
        expect(permit.permitted_mode?(0o005)).to be_truthy
      end
      it "permits 0o003" do
        expect(permit.permitted_mode?(0o003)).to be_truthy
      end
      it "does not permit 0o007" do
        expect(permit.permitted_mode?(0o007)).to be_falsey
      end
      it "does not permit 0o600" do
        expect(permit.permitted_mode?(0o600)).to be_falsey
      end
      it "does not permit 0o105" do
        expect(permit.permitted_mode?(0o105)).to be_falsey
      end
    end
  end
  describe "boundaries" do
    context "mode: -1" do
      let(:permit) { described_class.new(path:, mode: -1) }
      it "does not permit 0o005" do
        expect{permit.permitted_mode?(0o005)}.to raise_error(ArgumentError)
      end
    end
    context "mode: 0o1000" do
      let(:permit) { described_class.new(path:, mode: 0o1000) }
      it "does not permit 0o1000" do
        expect{permit.permitted_mode?(0o005)}.to raise_error(ArgumentError)
      end
    end
    context "mode: 0o777" do
      let(:permit) { described_class.new(path:, mode: 0o777) }
      it "permits 0o777" do
        expect(permit.permitted_mode?(0o777)).to be_truthy
      end
    end
    context "mode: 0o000" do
      let(:permit) { described_class.new(path:, mode: 0o000) }
      it "permits 0o000" do
        expect(permit.permitted_mode?(0o000)).to be_truthy
      end
    end
  end
end

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

  describe ".resolve" do
    let(:authority) { "example.com:8080" }

    it "creates a new Entitlement object from a URL" do
      entitlement_resolve = Terminalwire::Client::Entitlement.resolve(authority:)
      expect(entitlement_resolve.authority).to eq("example.com:8080")
    end

    context "terminalwire.com" do
      let(:authority) { "terminalwire.com" }
      let(:entitlement) { Terminalwire::Client::Entitlement.resolve(authority:) }
      it "returns RootPolicy" do
        expect(entitlement).to be_a Terminalwire::Client::Entitlement::RootPolicy
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

RSpec.describe Terminalwire::Client::Entitlement::RootPolicy do
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
    it "returns RootPolicy" do
      url = URI("https://terminalwire.com")
      expect(Terminalwire::Client::Entitlement.resolve(authority:)).to be_a Terminalwire::Client::Entitlement::RootPolicy
    end
  end
end
