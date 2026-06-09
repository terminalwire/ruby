# frozen_string_literal: true

require "spec_helper"

# Drives the conformance runner (Conformance.load) end-to-end over a corpus of
# real vectors. By default it points at the small SEED corpus committed under
# spec/corpus, which proves the loader mechanism works across every file shape
# (yml / json / sexp) and every typed sentinel ($bin / bin).
#
# In CI the full cross-impl corpus is mounted from terminalwire/protocol; setting
# TERMINALWIRE_CORPUS before the run makes these same specs validate it. We only
# override the env when it isn't already set, so an external corpus wins.
RSpec.describe Terminalwire::V2::Conformance do
  Conformance = Terminalwire::V2::Conformance
  Codec = Terminalwire::V2::Codec
  Negotiator = Terminalwire::V2::Negotiator

  SEED_CORPUS = File.expand_path("corpus", __dir__)
  USING_EXTERNAL_CORPUS = ENV.key?("TERMINALWIRE_CORPUS")

  around do |example|
    original = ENV["TERMINALWIRE_CORPUS"]
    ENV["TERMINALWIRE_CORPUS"] ||= SEED_CORPUS
    example.run
  ensure
    ENV["TERMINALWIRE_CORPUS"] = original
  end

  it "resolves the corpus root from TERMINALWIRE_CORPUS" do
    expect(Conformance.root.to_s).to eq(ENV.fetch("TERMINALWIRE_CORPUS"))
  end

  describe ".resolve (typed sentinels)" do
    it "resolves a { $bin } sentinel to a binary string" do
      out = Conformance.resolve("$bin" => "aGk=")
      expect(out).to eq("hi".b)
      expect(out.encoding).to eq(Encoding::ASCII_8BIT)
    end

    it "recurses through nested hashes and arrays" do
      out = Conformance.resolve("a" => [{ "$bin" => "AA==" }], "b" => { "c" => 1 })
      expect(out).to eq("a" => ["\x00".b], "b" => { "c" => 1 })
    end

    it "leaves scalars untouched" do
      expect(Conformance.resolve(7)).to eq(7)
      expect(Conformance.resolve("plain")).to eq("plain")
    end

    it "treats a multi-key hash with $bin as a normal map (not a sentinel)" do
      out = Conformance.resolve("$bin" => "aGk=", "extra" => 1)
      expect(out).to eq("$bin" => "aGk=", "extra" => 1)
    end
  end

  describe ".hex_to_bytes" do
    it "parses space-separated hex into a binary string" do
      expect(Conformance.hex_to_bytes("a1 74 ff")).to eq("\xa1\x74\xff".b)
    end
  end

  describe ".load failure mode" do
    it "fails loudly when the corpus directory is absent" do
      ENV["TERMINALWIRE_CORPUS"] = File.expand_path("does-not-exist", __dir__)
      expect { Conformance.load("golden") }
        .to raise_error(/conformance corpus not found/)
    end
  end

  describe "golden category" do
    let(:cases) { Conformance.load("golden") }

    it "loads at least one golden case" do
      expect(cases.size).to be > 0
    end

    it "encodes each frame to exactly the expected bytes (and round-trips)" do
      cases.each do |c|
        expected = Conformance.hex_to_bytes(c.fetch("bytes_hex"))
        frame = c.fetch("frame")
        expect(Codec.encode(frame)).to eq(expected), "encode mismatch for #{c['name']}"
        expect(Codec.decode(expected)).to eq(frame), "decode mismatch for #{c['name']}"
      end
    end
  end

  describe "negotiate category" do
    let(:cases) { Conformance.load("negotiate") }

    it "loads at least one negotiate case" do
      expect(cases.size).to be > 0
    end

    it "reproduces each expected decision" do
      cases.each do |c|
        result = Negotiator.negotiate(
          client_protocol: c.fetch("client_protocol"),
          client_capabilities: c.fetch("client_capabilities"),
          server_min: c.fetch("server_min"),
          server_max: c.fetch("server_max"),
          server_capabilities: c.fetch("server_capabilities")
        )
        expect(result[:decision]).to eq(c.fetch("decision")), "decision mismatch for #{c['name']}"
        if c["decision"] == "welcome"
          expect(result[:protocol]).to eq(c.fetch("protocol"))
          expect(result[:capabilities]).to eq(c.fetch("capabilities"))
        else
          expect(result[:supported]).to eq(
            min: c.fetch("supported").fetch("min"),
            max: c.fetch("supported").fetch("max")
          )
        end
      end
    end
  end

  describe "roundtrip category" do
    let(:cases) { Conformance.load("roundtrip") }

    it "loads cases from both yaml and json files" do
      expect(cases.size).to be > 0
    end

    it "survives encode -> decode unchanged" do
      cases.each do |c|
        frame = c.fetch("frame")
        expect(Codec.decode(Codec.encode(frame))).to eq(frame), "round-trip mismatch for #{c['name']}"
      end
    end
  end

  describe "session category (sexp tapes)" do
    let(:tapes) { Conformance.load("session") }

    it "loads at least one tape" do
      expect(tapes.size).to be > 0
    end

    it "parses a tape into the runner's step shape" do
      tape = tapes.first
      expect(tape).to include("name", "role", "config", "tape")
      expect(tape["role"]).to be_a(String)
    end

    it "gives server-role steps an emit list" do
      server = tapes.find { |t| t["role"] == "server" }
      expect(server["tape"]).to all(include("emit"))
    end

    it "groups client-role tapes into process/out/exit/stdout steps" do
      client = tapes.find { |t| t["role"] == "client" }
      expect(client).not_to be_nil
      expect(client["config"]).to include("origin")
      steps = client["tape"]
      expect(steps).to all(include("process", "out"))
      expect(steps.any? { |s| s.key?("stdout") }).to be(true)
      expect(steps.any? { |s| s.key?("exit") }).to be(true)
    end

    it "groups server-role do/event/reject actions" do
      server = tapes.find { |t| t["role"] == "server" && t["tape"].any? { |s| s.key?("do") } }
      expect(server).not_to be_nil
      steps = server["tape"]
      expect(steps.any? { |s| s.key?("do") }).to be(true)
      expect(steps.any? { |s| s["reject"] }).to be(true)
      events = steps.flat_map { |s| s.fetch("emit", []) }.select { |e| e.key?("event") }
      expect(events.first).to include("event" => "opened", "data" => { "path" => "/etc/hostname" })
    end

    it "resolves (bin ...) atoms inside tape frames to binary strings" do
      data_emits = tapes.flat_map { |t| t["tape"] }
                        .flat_map { |step| step.fetch("emit", []) }
                        .map { |e| e["send"] }.compact
                        .select { |f| f["t"] == "data" }
      expect(data_emits).not_to be_empty
      data_emits.each { |f| expect(f["bytes"].encoding).to eq(Encoding::ASCII_8BIT) }
    end
  end

  if USING_EXTERNAL_CORPUS
    it "is validating the externally-mounted corpus, not the seed" do
      expect(Conformance.root.to_s).to eq(File.expand_path(ENV.fetch("TERMINALWIRE_CORPUS")))
    end
  end
end
