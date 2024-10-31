require "spec_helper"
require "tempfile"

RSpec.describe Terminalwire::Cache::File::Store do
  let(:cache_dir) { Dir.mktmpdir }
  let(:store) { described_class.new(path: cache_dir) }
  let(:key) { "test_key" }
  let(:entry) { store.find(key) }

  after do
    FileUtils.remove_entry(cache_dir)
  end

  describe "#find" do
    subject { entry }

    it { is_expected.to be_a(Terminalwire::Cache::File::Entry) }

    it "generates the correct file path" do
      expect(subject.instance_variable_get(:@path).to_s).to eq(
        File.join(cache_dir, Terminalwire::Cache::File::Entry.key_path(key))
      )
    end
  end

  describe "#each" do
    subject { store.to_a }

    context "with no entries" do
      it { is_expected.to be_empty }
    end

    context "with entries" do
      before { entry.save }

      it "yields each entry in the directory" do
        expect(subject.count).to eq(1)
        expect(subject.first).to be_a(Terminalwire::Cache::File::Entry)
      end
    end
  end

  describe "#evict" do
    before do
      entry.value = "test_data"
      entry.expires = Time.now.utc - 3600
      entry.save
    end

    it "removes expired entries" do
      expect { store.evict }.to change { entry.persisted? }.from(true).to(false)
    end
  end

  describe "#destroy" do
    before { entry.save }

    it "deletes all entries" do
      expect { store.destroy }.to change { entry.persisted? }.from(true).to(false)
    end
  end
end

RSpec.describe Terminalwire::Cache::File::Entry do
  let(:cache_dir) { Dir.mktmpdir }
  let(:store) { Terminalwire::Cache::File::Store.new(path: cache_dir) }
  let(:key) { "test_key" }
  let(:entry) { store.find(key) }
  subject { entry }

  after do
    FileUtils.remove_entry(cache_dir)
  end

  describe "initial state" do
    it { is_expected.to be_miss }
    it { is_expected.to_not be_persisted }
    it { is_expected.to be_nil }
  end

  describe "#save" do
    let(:value) { "test_data" }
    let(:expires) { Time.now.utc + 3600 }

    before do
      entry.value = value
      entry.expires = expires
      entry.save
    end

    it { is_expected.to be_persisted }
    it { is_expected.to be_present }
    it { is_expected.to be_hit }

    it "writes data to the file" do
      expect(File.exist?(entry.instance_variable_get(:@path))).to be true
    end

    it "serializes data and expiration correctly" do
      serialized_data = MessagePack.unpack(File.read(entry.instance_variable_get(:@path)), symbolize_keys: true)
      expect(serialized_data[:value]).to eq(value)
      expect(Time.parse(serialized_data[:expires])).to be_within(1).of(expires)
    end
  end

  describe "#hit? and #miss?" do
    context "when the entry exists but is expired" do
      before do
        entry.value = "test_data"
        entry.expires = Time.now.utc - 3600
        entry.save
      end

      it { is_expected.to be_miss }
      it { is_expected.to_not be_hit }
    end

    context "when the entry exists and is not expired" do
      before do
        entry.value = "test_data"
        entry.expires = Time.now.utc + 3600
        entry.save
      end

      it { is_expected.to be_hit }
      it { is_expected.to_not be_miss }
    end

    context "when the entry has a nil value and is not expired" do
      before do
        entry.value = nil
        entry.expires = Time.now.utc + 3600
        entry.save
      end

      it { is_expected.to be_hit }
      it { is_expected.to_not be_miss }
    end
  end

  describe "#expired?" do
    context "when no expiration is set" do
      before { entry.value = "test_data" }
      it { is_expected.to_not be_expired }
    end

    context "when the entry is expired" do
      before do
        entry.value = "test_data"
        entry.expires = Time.now.utc - 3600
      end
      it { is_expected.to be_expired }
    end

    context "when the entry is not expired" do
      before do
        entry.value = "test_data"
        entry.expires = Time.now.utc + 3600
      end
      it { is_expected.to_not be_expired }
    end
  end

  describe "#deserialize" do
    let(:value) { "test_data" }
    let(:expires) { Time.now.utc + 3600 }

    before do
      entry.value = value
      entry.expires = expires
      entry.save
    end

    it "loads the value and expiration from the file" do
      new_entry = store.find(key)
      expect(new_entry.value).to eq(value)
      expect(new_entry.expires).to be_within(1).of(expires)
    end
  end

  describe "#destroy" do
    before { entry.save }

    it "deletes the cache file" do
      expect { entry.destroy }.to change { File.exist?(entry.instance_variable_get(:@path)) }.from(true).to(false)
    end
  end
end
