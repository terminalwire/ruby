require "spec_helper"

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
