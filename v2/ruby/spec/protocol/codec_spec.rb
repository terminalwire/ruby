# frozen_string_literal: true

require "spec_helper"

RSpec.describe Terminalwire::V2::Codec do
  Codec = Terminalwire::V2::Codec
  ProtocolError = Terminalwire::V2::ProtocolError

  describe ".encode" do
    it "round-trips a well-formed frame" do
      frame = { "t" => "data", "sid" => 3, "bytes" => "hi".b }
      expect(Codec.decode(Codec.encode(frame))).to eq(frame)
    end

    it "produces binary (ASCII-8BIT) msgpack bytes" do
      bytes = Codec.encode("t" => "exit", "sid" => 0, "status" => 0)
      expect(bytes.encoding).to eq(Encoding::ASCII_8BIT)
    end

    it "raises ProtocolError when the frame is not a Hash" do
      expect { Codec.encode([1, 2, 3]) }
        .to raise_error(ProtocolError, /frame must be a Hash, got Array/)
    end

    it "raises ProtocolError on nil" do
      expect { Codec.encode(nil) }.to raise_error(ProtocolError, /frame must be a Hash/)
    end
  end

  describe ".decode" do
    it "decodes a control frame" do
      frame = { "t" => "welcome", "sid" => 0, "protocol" => 2 }
      expect(Codec.decode(Codec.encode(frame))).to eq(frame)
    end

    it "normalizes every integer kind to a plain Integer (Go's int64)" do
      # MessagePack picks the narrowest int wire format on encode; decode must
      # always yield a plain Ruby Integer regardless. Cover small, byte, and the
      # signed-64-bit ceiling (MAX_SID).
      [0, 1, 127, 255, 65_535, (1 << 31), Codec::MAX_SID].each do |n|
        decoded = Codec.decode(Codec.encode("t" => "window_adjust", "sid" => 1, "bytes" => n))
        expect(decoded["bytes"]).to be_a(Integer)
        expect(decoded["bytes"]).to eq(n)
      end
    end

    it "accepts sid 0 (the control stream)" do
      expect(Codec.decode(Codec.encode("t" => "hello", "sid" => 0))).to include("sid" => 0)
    end

    it "accepts sid at MAX_SID" do
      frame = { "t" => "data", "sid" => Codec::MAX_SID, "bytes" => "".b }
      expect(Codec.decode(Codec.encode(frame))["sid"]).to eq(Codec::MAX_SID)
    end

    it "preserves binary payloads losslessly" do
      payload = (0..255).to_a.pack("C*")
      frame = { "t" => "data", "sid" => 5, "bytes" => payload }
      decoded = Codec.decode(Codec.encode(frame))
      expect(decoded["bytes"]).to eq(payload)
      expect(decoded["bytes"].encoding).to eq(Encoding::ASCII_8BIT)
    end

    context "malformed input" do
      it "raises ProtocolError on non-msgpack garbage" do
        expect { Codec.decode("\xFF\xFF\xFF not msgpack") }
          .to raise_error(ProtocolError, /malformed msgpack/)
      end

      it "raises ProtocolError on truncated bytes" do
        bytes = Codec.encode("t" => "data", "sid" => 1, "bytes" => "hi".b)
        expect { Codec.decode(bytes[0..2]) }.to raise_error(ProtocolError)
      end

      it "raises ProtocolError when the top-level object is not a map" do
        expect { Codec.decode(MessagePack.pack([1, 2, 3])) }
          .to raise_error(ProtocolError, /frame must be a map/)
      end

      it "raises ProtocolError when the top-level object is a scalar" do
        expect { Codec.decode(MessagePack.pack(42)) }
          .to raise_error(ProtocolError, /frame must be a map/)
      end
    end

    context "frame type 't'" do
      it "raises when 't' is missing" do
        expect { Codec.decode(MessagePack.pack("sid" => 0)) }
          .to raise_error(ProtocolError, /missing string 't'/)
      end

      it "raises when 't' is empty (cross-impl: Go/Elixir reject at the codec)" do
        expect { Codec.decode(MessagePack.pack("t" => "", "sid" => 0)) }
          .to raise_error(ProtocolError, /missing string 't'/)
      end

      it "raises when 't' is not a string" do
        expect { Codec.decode(MessagePack.pack("t" => 7, "sid" => 0)) }
          .to raise_error(ProtocolError, /missing string 't'/)
      end
    end

    context "stream id 'sid'" do
      it "raises when 'sid' is missing" do
        expect { Codec.decode(MessagePack.pack("t" => "data")) }
          .to raise_error(ProtocolError, /missing integer 'sid'/)
      end

      it "raises when 'sid' is negative" do
        expect { Codec.decode(MessagePack.pack("t" => "data", "sid" => -1)) }
          .to raise_error(ProtocolError, /missing integer 'sid'/)
      end

      it "raises when 'sid' is not an integer" do
        expect { Codec.decode(MessagePack.pack("t" => "data", "sid" => "3")) }
          .to raise_error(ProtocolError, /missing integer 'sid'/)
      end

      it "raises when 'sid' exceeds MAX_SID (would wrap negative in Go's int64)" do
        expect { Codec.decode(MessagePack.pack("t" => "data", "sid" => Codec::MAX_SID + 1)) }
          .to raise_error(ProtocolError, /missing integer 'sid'/)
      end
    end
  end
end
