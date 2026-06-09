# frozen_string_literal: true

require "spec_helper"

RSpec.describe Terminalwire::V2::Window do
  Window = Terminalwire::V2::Window
  Protocol = Terminalwire::V2::Protocol

  describe "#initialize" do
    it "starts with the offered size" do
      expect(Window.new(1024).available).to eq(1024)
    end

    it "clamps an oversized initial offer to MAX_WINDOW" do
      expect(Window.new(Protocol::MAX_WINDOW + 1).available).to eq(Protocol::MAX_WINDOW)
    end
  end

  describe "#take" do
    it "takes the full amount when credit is available" do
      w = Window.new(100)
      expect(w.take(40)).to eq(40)
      expect(w.available).to eq(60)
    end

    it "takes only what is available when the request exceeds credit" do
      w = Window.new(30)
      expect(w.take(100)).to eq(30)
      expect(w.available).to eq(0)
    end

    it "takes nothing from an exhausted window" do
      w = Window.new(0)
      expect(w.take(10)).to eq(0)
      expect(w.available).to eq(0)
    end

    it "never goes negative" do
      w = Window.new(5)
      w.take(5)
      expect(w.take(1)).to eq(0)
      expect(w.available).to eq(0)
    end

    it "clamps a negative request to zero (defensive guard)" do
      w = Window.new(10)
      expect(w.take(-4)).to eq(0)
      expect(w.available).to eq(10)
    end
  end

  describe "#grant" do
    it "extends the window by the granted bytes" do
      w = Window.new(10)
      w.take(10)
      w.grant(50)
      expect(w.available).to eq(50)
    end

    it "clamps a grant to the protocol ceiling" do
      w = Window.new(Protocol::MAX_WINDOW)
      w.grant(1_000_000)
      expect(w.available).to eq(Protocol::MAX_WINDOW)
    end
  end
end
