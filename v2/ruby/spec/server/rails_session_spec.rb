# frozen_string_literal: true

require "spec_helper"
require "base64"
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

  it "persists values across a fresh read (round-trip, string keys)" do
    session["user_id"] = 42
    fresh = described_class.new(context: ctx, secret_key: secret)
    expect(fresh["user_id"]).to eq(42)
  end

  it "stores the payload ENCRYPTED — nothing recoverable from the file without the key" do
    session["api_token"] = "tw_live_supersecret"
    raw = ctx.file.read(path_for(ctx))

    # Decode every base64-looking segment of the stored blob (JWTs split on ".",
    # MessageEncryptor on "--"); the plaintext must not appear in any of them.
    decoded = raw.split(/--|\./).map do |segment|
      Base64.decode64(segment.tr("-_", "+/"))
    rescue StandardError
      ""
    end
    expect(raw).not_to include("supersecret")
    expect(decoded.join).not_to include("supersecret")
  end

  it "is SIGNED — a tampered ciphertext fails authentication and reads empty" do
    session["user_id"] = 42
    raw = ctx.file.read(path_for(ctx)).dup

    # Flip one base64 byte inside the ciphertext (index 5 is well inside the first
    # segment, before the "--" delimiters). AES-256-GCM's auth tag no longer matches.
    raw[5] = (raw[5] == "A" ? "B" : "A")
    ctx.file.write(path_for(ctx), raw)

    # The encryptor itself rejects it — this is the signature (GCM auth tag) doing its job.
    expect { session.send(:encryptor).decrypt_and_verify(raw) }
      .to raise_error(ActiveSupport::MessageEncryptor::InvalidMessage)
    # And the Session degrades to empty rather than trusting the mutated payload.
    fresh = described_class.new(context: ctx, secret_key: secret)
    expect(fresh.read).to eq({})
    expect(fresh["user_id"]).to be_nil
  end

  it "uses an authenticated (AEAD) cipher, not a bare/unauthenticated one" do
    # aes-256-gcm is authenticated encryption: encrypt AND sign in one primitive.
    # Guard against a regression to an unauthenticated cipher (encrypt-only, forgeable).
    cipher = session.send(:encryptor).instance_variable_get(:@cipher)
    expect(cipher).to match(/gcm\z/i)
  end

  it "round-trips through the real encryptor and rejects a foreign key's ciphertext" do
    session["user_id"] = 42
    token = ctx.file.read(path_for(ctx))

    # Same derived key decrypts; a session built on a different secret cannot.
    expect(session.send(:encryptor).decrypt_and_verify(token)).to eq("user_id" => 42)
    other = described_class.new(context: FakeContext.new, secret_key: "rotated-secret")
    expect { other.send(:encryptor).decrypt_and_verify(token) }
      .to raise_error(ActiveSupport::MessageEncryptor::InvalidMessage)
  end

  it "reads a legacy signed-only JWT session and rewrites it encrypted (no logout on upgrade)" do
    legacy = JWT.encode({ "user_id" => 42 }, secret, "HS256")
    ctx.file.write(path_for(ctx), legacy)

    expect(session.read).to eq("user_id" => 42)

    migrated = ctx.file.read(path_for(ctx))
    expect(migrated).not_to eq(legacy)
    expect { JWT.decode(migrated, secret, true, algorithm: "HS256") }.to raise_error(JWT::DecodeError)
    expect(described_class.new(context: ctx, secret_key: secret).read).to eq("user_id" => 42)
  end

  it "reads a legacy JWT signed with a different secret as empty" do
    ctx.file.write(path_for(ctx), JWT.encode({ "user_id" => 42 }, "rotated-secret", "HS256"))
    expect(session.read).to eq({})
  end

  it "expires: a stale session reads as empty (log in again)" do
    short = described_class.new(context: ctx, secret_key: secret, expires_in: 0.01)
    short["user_id"] = 42
    sleep 0.05
    expect(short.read).to eq({})
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
