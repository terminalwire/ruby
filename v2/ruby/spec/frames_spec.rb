# frozen_string_literal: true

require "spec_helper"

RSpec.describe Terminalwire::V2::Frames do
  Frames = Terminalwire::V2::Frames
  Protocol = Terminalwire::V2::Protocol

  it "string-keys every builder's output so frames are uniformly wire-shaped" do
    frames = [
      Frames.hello(protocol: 2, capabilities: [], program: "x", entitlement: {}),
      Frames.window_adjust(sid: 1, bytes: 10),
      Frames.signal("resize"),
      Frames.resize(cols: 80, rows: 24),
      Frames.interrupt,
      Frames.welcome(protocol: 2, capabilities: []),
      Frames.incompatible(supported: { min: 2, max: 2 }, message: "x"),
      Frames.exit(status: 0),
      Frames.open(sid: 1, stream: "stdout"),
      Frames.data(sid: 1, bytes: "x"),
      Frames.close(sid: 1),
      Frames.request(sid: 1, resource: "file", method: "read"),
      Frames.response_ok(sid: 1, value: nil),
      Frames.response_error(sid: 1, code: "io", message: "boom")
    ]
    frames.each { |f| expect(f.keys).to all(be_a(String)) }
  end

  describe ".hello" do
    it "carries the control sid, type, and defaults for terminal/flow" do
      frame = Frames.hello(protocol: 2, capabilities: %w[stdio], program: "demo", entitlement: { "x" => 1 })
      expect(frame).to include(
        "t" => Protocol::Type::HELLO,
        "sid" => Protocol::CONTROL_SID,
        "protocol" => 2,
        "capabilities" => %w[stdio],
        "program" => "demo",
        "entitlement" => { "x" => 1 },
        "terminal" => Frames::DEFAULT_TERMINAL,
        "flow" => Frames::DEFAULT_FLOW
      )
    end

    it "accepts an explicit terminal and flow override" do
      term = { "device" => { "cols" => 10 } }
      frame = Frames.hello(protocol: 2, capabilities: [], program: "x", entitlement: {},
                           terminal: term, flow: { "window" => 1 })
      expect(frame).to include("terminal" => term, "flow" => { "window" => 1 })
    end

    it "defaults flow to DEFAULT_WINDOW" do
      expect(Frames::DEFAULT_FLOW).to eq("window" => Protocol::DEFAULT_WINDOW)
    end
  end

  describe ".signal" do
    it "merges payload into a control-sid signal frame" do
      expect(Frames.signal("resize", "cols" => 80))
        .to eq("t" => Protocol::Type::SIGNAL, "sid" => Protocol::CONTROL_SID, "name" => "resize", "cols" => 80)
    end

    it "defaults to an empty payload" do
      expect(Frames.signal("interrupt"))
        .to eq("t" => Protocol::Type::SIGNAL, "sid" => Protocol::CONTROL_SID, "name" => "interrupt")
    end
  end

  describe ".resize" do
    it "is a resize signal carrying cols/rows" do
      expect(Frames.resize(cols: 120, rows: 40))
        .to include("name" => Protocol::Signal::RESIZE, "cols" => 120, "rows" => 40)
    end
  end

  describe ".interrupt" do
    it "is an interrupt signal with no payload" do
      expect(Frames.interrupt).to eq(Frames.signal(Protocol::Signal::INTERRUPT))
    end
  end

  describe ".incompatible" do
    it "normalizes symbol-keyed supported ranges to string keys" do
      frame = Frames.incompatible(supported: { min: 2, max: 5 }, message: "too old")
      expect(frame["supported"]).to eq("min" => 2, "max" => 5)
    end

    it "accepts a string-keyed supported range too" do
      frame = Frames.incompatible(supported: { "min" => 1, "max" => 9 }, message: "x")
      expect(frame["supported"]).to eq("min" => 1, "max" => 9)
    end
  end

  describe ".open" do
    it "omits mode when not given (output streams have no line discipline)" do
      frame = Frames.open(sid: 2, stream: "stdout")
      expect(frame).not_to have_key("mode")
    end

    it "includes mode when given (input streams carry it)" do
      frame = Frames.open(sid: 2, stream: "stdin-raw", mode: Protocol::Mode::RAW)
      expect(frame).to include("mode" => "raw")
    end
  end

  describe ".data" do
    it "forces the payload to binary encoding" do
      frame = Frames.data(sid: 1, bytes: "café")
      expect(frame["bytes"].encoding).to eq(Encoding::ASCII_8BIT)
    end
  end

  describe ".response_ok / .response_error" do
    it "marks ok true and carries the value" do
      expect(Frames.response_ok(sid: 3, value: { "a" => 1 }))
        .to include("ok" => true, "value" => { "a" => 1 })
    end

    it "marks ok false and nests the error" do
      expect(Frames.response_error(sid: 3, code: "denied", message: "nope"))
        .to include("ok" => false, "error" => { "code" => "denied", "message" => "nope" })
    end
  end

  describe ".request" do
    it "defaults params to an empty hash" do
      expect(Frames.request(sid: 1, resource: "file", method: "read")["params"]).to eq({})
    end
  end
end
