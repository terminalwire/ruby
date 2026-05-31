# frozen_string_literal: true

module Terminalwire2
  module Server
    # The server's live view of the client's terminal. Seeded from the hello's
    # `terminal` block and updated by `resize` frames as the user resizes their
    # window. Thread-safe because the read pump writes it while the CLI thread
    # reads it.
    class Terminal
      def initialize(cols: 80, rows: 24, tty: false, color: false, term: "")
        @cols = cols
        @rows = rows
        @tty = tty
        @color = color
        @term = term
        @mutex = Mutex.new
      end

      def cols = @mutex.synchronize { @cols }
      def rows = @mutex.synchronize { @rows }
      def term = @mutex.synchronize { @term }
      def tty? = @mutex.synchronize { @tty }
      def color? = @mutex.synchronize { @color }

      # IO#winsize convention: [rows, cols]. Lets the Thor IO proxy answer
      # winsize so tty-screen/tty-table can size to the client.
      def winsize = @mutex.synchronize { [@rows, @cols] }

      # Apply a wire `terminal` block (string keys) from a hello frame.
      def apply(block)
        return if block.nil?

        @mutex.synchronize do
          @cols = block["cols"] if block["cols"]
          @rows = block["rows"] if block["rows"]
          @tty = block["tty"] unless block["tty"].nil?
          @color = block["color"] unless block["color"].nil?
          @term = block["term"] if block["term"]
        end
      end

      # Apply a resize.
      def resize(cols:, rows:)
        @mutex.synchronize do
          @cols = cols if cols
          @rows = rows if rows
        end
      end
    end
  end
end
