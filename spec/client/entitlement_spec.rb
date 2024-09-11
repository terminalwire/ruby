require 'spec_helper'
require 'pathname'
require 'uri'
require 'rspec'

RSpec.describe Terminalwire::Client::Entitlement::Paths do
  let(:paths) { described_class.new }

  describe '#permit' do
    it 'adds a permitted path to the @permitted list' do
      path = '/some/path'
      expanded_path = Pathname.new(path).expand_path

      paths.permit(path)
      expect(paths).to include(expanded_path)
    end
  end

  describe '#permitted?' do
    before do
      paths.permit('/approved/path/**/*')
    end

    it 'returns true if the path matches any permitted path' do
      expect(paths.permitted?('/approved/path/file.txt')).to be_truthy
    end

    it 'returns false if the path does not match any permitted path' do
      expect(paths.permitted?('/unapproved/path/file.txt')).to be_falsey
    end
  end
end

RSpec.describe Terminalwire::Client::Entitlement do
  let(:authority) { 'localhost:3000' }
  let(:entitlement) { described_class.new(authority: authority) }

  describe '#initialize' do
    it 'sets the authority attribute' do
      expect(entitlement.authority).to eq(authority)
    end

    it 'initializes the paths and permits the domain directory' do
      permitted_path = Pathname.new("~/.terminalwire/domains/#{authority}/files/junk.txt")
      expect(entitlement.paths.permitted?(permitted_path)).to be_truthy
    end
  end

  describe '.from_url' do
    it 'creates a new Entitlement object from a URL' do
      url = URI.parse('ws://example.com:8080')
      entitlement_from_url = described_class.from_url(url)
      expect(entitlement_from_url.authority).to eq('example.com:8080')
    end

    it 'uses only the host as authority if the port is default' do
      url = URI.parse('wss://example.com')
      entitlement_from_url = described_class.from_url(url)
      expect(entitlement_from_url.authority).to eq('example.com')
    end
  end
end
