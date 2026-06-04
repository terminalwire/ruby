# frozen_string_literal: true

module Terminalwire::V2
  module Server
    # An IO-shaped object backed by the Terminalwire Context. This is the
    # universal adapter: anything that writes to an IO (Kernel#puts, OptionParser
    # help/errors, Logger, a library's `output:`) or reads from one (`$stdin.gets`)
    # works against the client's terminal when handed one of these.
    #
    # `Server.redirect` swaps the global $stdout/$stderr/$stdin for these so an
    # ordinary CLI needs no Terminalwire-specific code; Thor uses them directly
    # because its shell captures the streams at construction.
    class IO
      # @param context [Context]
      # @param stream [:stdout, :stderr, :stdin]
      def initialize(context, stream)
        @context = context
        @stream = stream
      end

      # --- writing (stdout/stderr) ---

      def print(*args)
        args.each { |arg| @context.print(arg.to_s, stream: @stream) }
        nil
      end

      def write(*args)
        args.sum { |arg| s = arg.to_s; @context.print(s, stream: @stream); s.bytesize }
      end

      def <<(arg)
        @context.print(arg.to_s, stream: @stream)
        self
      end

      def puts(*args)
        if args.empty?
          @context.print("\n", stream: @stream)
        else
          args.flatten.each { |arg| @context.print("#{arg}\n", stream: @stream) }
        end
        nil
      end

      def printf(format, *args)
        print(format % args)
      end

      def flush = self
      def sync = true
      def sync=(value)
        value
      end

      # --- reading (stdin) ---

      def gets(*) = @context.stdin.gets
      def getpass(*) = @context.stdin.getpass
      def read = @context.stdin.read

      def each_line(&block)
        return enum_for(:each_line) unless block

        while (line = gets)
          block.call(line)
        end
      end
      alias each each_line

      # --- terminal reflection (so tty-screen/tty-table/pastel target the client) ---

      # Per-stream: this proxy's own stream is what isatty(stdout) etc. ask about.
      def tty? = @context.terminal.stream(@stream).tty?
      def winsize = @context.terminal.winsize
      def isatty = tty?

      # Answer the window-size ioctl (TIOCGWINSZ) that tty-screen probes, filling
      # the caller's buffer with the CLIENT's [rows, cols] — so tty-screen-based
      # libraries (tty-progressbar, tty-spinner, …) size to the client instead of
      # crashing on a non-IO stream. Other ioctls are no-ops.
      def ioctl(_cmd, buf = nil)
        if buf.is_a?(String)
          rows, cols = @context.terminal.winsize
          buf[0, 8] = [rows.to_i, cols.to_i, 0, 0].pack("S4") # matches tty-screen's "SSSS"
        end
        0
      end
    end
  end
end
