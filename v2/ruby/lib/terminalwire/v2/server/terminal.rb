# frozen_string_literal: true

module Terminalwire::V2
  module Server
    # The server's live model of the client's terminal. See ../../../TERMINAL.md.
    #
    # Two orthogonal parts, deliberately not conflated:
    #   * three Streams (stdin/stdout/stderr), each independently tty/pipe/file/null
    #   * one Device (the controlling terminal): size, term, color, encoding, mode
    #
    # Seeded from the hello `terminal` block; the device's size/mode are updated by
    # control frames. Thread-safe: the read pump writes while the CLI reads.
    class Terminal
      # A standard stream and what it's connected to. Kind is fixed for the
      # session (a stream doesn't turn from a pipe into a tty mid-run).
      Stream = Data.define(:kind) do
        def tty?  = kind == "tty"
        def pipe? = kind == "pipe"
        def file? = kind == "file"
        def null? = kind == "null"
      end

      attr_reader :stdin, :stdout, :stderr

      def initialize(stdin: "tty", stdout: "tty", stderr: "tty",
                     cols: 80, rows: 24, xpixels: 0, ypixels: 0,
                     term: "", color: "none", encoding: "UTF-8", mode: "cooked")
        @stdin = Stream.new(kind: stdin)
        @stdout = Stream.new(kind: stdout)
        @stderr = Stream.new(kind: stderr)
        @cols = cols
        @rows = rows
        @xpixels = xpixels
        @ypixels = ypixels
        @term = term
        @color = color
        @encoding = encoding
        @mode = mode
        @mutex = Mutex.new
      end

      # Device attributes.
      def cols     = @mutex.synchronize { @cols }
      def rows     = @mutex.synchronize { @rows }
      def xpixels  = @mutex.synchronize { @xpixels }
      def ypixels  = @mutex.synchronize { @ypixels }
      def term     = @mutex.synchronize { @term }
      def encoding = @mutex.synchronize { @encoding }
      def color    = @mutex.synchronize { @color }
      def mode     = @mutex.synchronize { @mode }

      def color? = color != "none"

      # A controlling terminal device exists iff some stream is a tty.
      def device? = @stdin.tty? || @stdout.tty? || @stderr.tty?

      # IO#winsize convention: [rows, cols].
      def winsize = @mutex.synchronize { [@rows, @cols] }

      # Look up a stream by name (:stdin/:stdout/:stderr).
      def stream(name)
        { stdin: @stdin, stdout: @stdout, stderr: @stderr }.fetch(name.to_sym)
      end

      # Apply a wire `terminal` block (string keys) from a hello frame.
      def apply(block)
        return if block.nil?

        @stdin  = Stream.new(kind: block.dig("stdin", "kind") || @stdin.kind)
        @stdout = Stream.new(kind: block.dig("stdout", "kind") || @stdout.kind)
        @stderr = Stream.new(kind: block.dig("stderr", "kind") || @stderr.kind)

        device = block["device"]
        return if device.nil?

        @mutex.synchronize do
          @cols = device["cols"] if device["cols"]
          @rows = device["rows"] if device["rows"]
          @xpixels = device["xpixels"] if device["xpixels"]
          @ypixels = device["ypixels"] if device["ypixels"]
          @term = device["term"] if device["term"]
          @color = device["color"] if device["color"]
          @encoding = device["encoding"] if device["encoding"]
          @mode = device["mode"] if device["mode"]
        end
      end

      # Apply a resize control frame.
      def resize(cols:, rows:, xpixels: nil, ypixels: nil)
        @mutex.synchronize do
          @cols = cols if cols
          @rows = rows if rows
          @xpixels = xpixels if xpixels
          @ypixels = ypixels if ypixels
        end
      end
    end
  end
end
