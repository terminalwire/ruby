# frozen_string_literal: true

module Terminalwire2
  module Server
    # Runs a block with Ruby's standard I/O globals pointed at the client's
    # terminal, so an ordinary CLI — OptionParser, GLI, dry-cli, or bare
    # Kernel#puts/gets — streams to/from the client with no Terminalwire-specific
    # code.
    #
    #   Terminalwire2::Server.redirect(context, argv: args) do
    #     OptionParser.new { |o| ... }.parse!(args)   # help/errors -> client
    #     puts "done"                                 # -> client
    #   end
    #
    # Concurrency-safe by design. We do NOT swap the process-global $stdout per
    # command (that interleaves when two run at once). Instead we install a
    # StreamRouter as $stdout/$stderr/$stdin ONCE, and each call to #redirect binds
    # a fiber-local target. Two commands running concurrently — on different
    # threads (Puma) or fibers (Falcon) — each see their own client and never cross
    # streams. Outside a #redirect block the routers delegate to the real streams,
    # so installing them is transparent to the rest of the process.
    module_function

    STDOUT_KEY = :terminalwire_stdout
    STDERR_KEY = :terminalwire_stderr
    STDIN_KEY  = :terminalwire_stdin

    # Install the routers as the global streams, once per process. Idempotent and
    # thread-safe. Safe to leave installed: with no fiber-local target they pass
    # straight through to the original $stdout/$stderr/$stdin.
    @install_mutex = Mutex.new

    def install!
      @install_mutex.synchronize do
        return if @installed

        $stdout = StreamRouter.new(STDOUT_KEY, $stdout)
        $stderr = StreamRouter.new(STDERR_KEY, $stderr)
        $stdin  = StreamRouter.new(STDIN_KEY, $stdin)
        @installed = true
      end
    end

    def installed? = @installed == true

    # Run the block with this fiber's standard streams pointed at `context`.
    #
    # `argv:` is accepted for convenience but ARGV / $PROGRAM_NAME are genuinely
    # process-global (Ruby has no fiber-local ARGV), so we pass the arguments to
    # the block instead of mutating ARGV — the Handler hands them to your CLI
    # directly. We deliberately do NOT mutate global ARGV here, to avoid the exact
    # cross-command races this method exists to prevent.
    def redirect(context, argv: nil)
      install!

      out = IO.new(context, :stdout)
      err = IO.new(context, :stderr)
      in_ = IO.new(context, :stdin)

      prev_out = $stdout.__bind__(out)
      prev_err = $stderr.__bind__(err)
      prev_in  = $stdin.__bind__(in_)

      yield(out: out, err: err, in: in_, argv: argv)
    ensure
      $stdout.__restore__(prev_out)
      $stderr.__restore__(prev_err)
      $stdin.__restore__(prev_in)
    end
  end
end
