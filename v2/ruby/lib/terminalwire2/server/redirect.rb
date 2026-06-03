# frozen_string_literal: true

module Terminalwire2
  module Server
    # Runs a block with Ruby's standard I/O globals pointed at the client's
    # terminal, so an ordinary CLI — OptionParser, GLI, dry-cli, or bare
    # Kernel#puts/gets — streams to/from the client with no Terminalwire-specific
    # code. Restores the originals afterward, always.
    #
    #   Terminalwire2::Server.redirect(context) do
    #     parser = OptionParser.new { |o| ... }   # its help/errors -> client
    #     parser.parse!(args)
    #     puts "done"                              # -> client
    #   end
    #
    # Note: this redirects the *global* streams, so it is process-wide for the
    # duration of the block. A threaded server should run one command per thread
    # and rely on thread-local fibers, OR serialize; for the common Rails/ActionCable
    # case each session already runs on its own thread. See `redirect_thread_safe`
    # below for the fiber/thread-local-safe variant when available.
    module_function

    def redirect(context, argv: nil)
      out = IO.new(context, :stdout)
      err = IO.new(context, :stderr)
      in_ = IO.new(context, :stdin)

      old = { out: $stdout, err: $stderr, in: $stdin, argv: ARGV.dup, prog: $PROGRAM_NAME }

      $stdout = out
      $stderr = err
      $stdin = in_
      if argv
        ARGV.replace(argv)
        $PROGRAM_NAME = context.program_name if context.respond_to?(:program_name) && context.program_name
      end

      yield(out: out, err: err, in: in_)
    ensure
      $stdout = old[:out]
      $stderr = old[:err]
      $stdin = old[:in]
      ARGV.replace(old[:argv])
      $PROGRAM_NAME = old[:prog]
    end
  end
end
