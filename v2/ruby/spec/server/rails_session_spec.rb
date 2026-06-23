# frozen_string_literal: true

require "spec_helper"
require "terminalwire/v2/rails"

RSpec.describe Terminalwire::V2::Rails::Session do
  # An in-memory stand-in for the client: file.read on a missing path raises, just
  # like a real file.read request that comes back :not_found.
  class FakeContext
    def initialize = @files = {}
    def storage_path = "/home/user/.terminalwire/storage/example"
    def file = File.new(@files)
    def directory = Directory.new

    class File
      def initialize(store) = @store = store
      def read(path) = @store.fetch(path.to_s) { raise "no such file: #{path}" }
      def write(path, content) = @store[path.to_s] = content
      def exist?(path) = @store.key?(path.to_s)
      def delete(path) = @store.delete(path.to_s)
    end

    class Directory
      def create(_path) = true
    end
  end

  let(:secret) { "test-secret-key-base" }
  let(:ctx) { FakeContext.new }
  subject(:session) { described_class.new(context: ctx, secret_key: secret) }

  def path_for(context) = Pathname.new(context.storage_path).join(described_class::FILENAME)

  it "starts empty" do
    expect(session.read).to eq({})
    expect(session["user_id"]).to be_nil
    expect(session.dig("user_id")).to be_nil
  end

  it "persists values across a fresh read (JWT round-trip, string keys)" do
    session["user_id"] = 42
    fresh = described_class.new(context: ctx, secret_key: secret)
    expect(fresh["user_id"]).to eq(42)
  end

  it "reads as empty — not a crash — when the token is garbage/tampered" do
    ctx.file.write(path_for(ctx), "not-a-jwt")
    expect(session.read).to eq({})
  end

  it "reads as empty when signed with a different secret (i.e. log in again)" do
    session["user_id"] = 42
    other = described_class.new(context: ctx, secret_key: "rotated-secret")
    expect(other.read).to eq({})
  end

  it "reads as empty when the session file is missing entirely" do
    ctx.file.delete(path_for(ctx))
    expect(session.read).to eq({})
  end

  it "reset clears the session" do
    session["user_id"] = 42
    session.reset
    expect(session.read).to eq({})
  end
end
