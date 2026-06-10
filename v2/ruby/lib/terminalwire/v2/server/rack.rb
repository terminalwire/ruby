# frozen_string_literal: true

require "digest"
require_relative "handler"
require_relative "../transport/queue"
# NOTE: the async stack (async, async-websocket) is required lazily, only when a
# request actually arrives inside an Async reactor (Falcon). Threaded servers
# (Puma & friends) and the frame parser never load it — see #call / #async_reactor?.

module Terminalwire; end
module Terminalwire::V2
  module Server
    # A Rack endpoint that serves a Terminalwire CLI over a WebSocket. Mounting it
    # is the entire integration:
    #
    #   # config/routes.rb
    #   mount Terminalwire::V2::Server::Rack.new(MyCLI), at: "/terminal"
    #
    # It runs on threaded servers (Puma, and friends) and on async servers (Falcon)
    # alike. The server runtime is thread-based, so each connection runs its CLI on
    # its own thread; this class owns that thread, the WebSocket framing, and the
    # teardown — the host app never sees any of it.
    #
    # Two server worlds, picked per request by whether we're inside an async
    # reactor (Async::Task.current?):
    #
    #   * Threaded (Puma): a raw RFC 6455 upgrade whose streaming body does the
    #     framing on plain blocking socket I/O in threads — exactly what the
    #     thread-based runtime and Puma's socket want (no async reactor fighting
    #     Puma's write-timeout watchdog).
    #   * Async (Falcon): async-websocket drives the connection in reactor fibers,
    #     bridged to the runtime's threads via a queue + a wake pipe.
    #
    # Opt-in require: require "terminalwire/v2/server/rack". The async stack is
    # pulled in lazily and only on the Falcon path, so Puma deployments (and the
    # frame parser in unit tests) never load async/async-websocket at all.
    class Rack
      WS_GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

      # @param cli_class [Class] a Thor CLI that includes Terminalwire::V2::Server::Thor
      # @param verbose [Boolean] send full backtraces to the client (dev only)
      # @param report [#call, nil] optional callable invoked with unexpected errors
      def initialize(cli_class, verbose: false, report: nil)
        @handler = Handler.new(cli_class: cli_class, verbose: verbose, report: report)
      end

      def call(env)
        return upgrade_required unless websocket?(env)
        # The request host — threaded into the session so server-side URL helpers
        # (login, `browser open`, license) can build absolute URLs, as v1 did.
        host = env["HTTP_HOST"]

        if async_reactor?
          # Async server (Falcon): let async-websocket own the connection. Pull the
          # adapter in here — this is the only path that needs the async stack.
          # :nocov: Falcon transport wiring — exercised live by the conformance suite, not units.
          require "async/websocket/adapters/rack"
          Async::WebSocket::Adapters::Rack.open(env) { |connection| ReactorBridge.new(connection, @handler, host: host).run }
          # :nocov:
        else
          # Threaded server (Puma & friends): hand-roll the upgrade and stream.
          [101, upgrade_headers(env), ThreadBridge.new(@handler, host: host)]
        end
      end

      private

      # Are we running inside an Async reactor (Falcon)? If the async gem isn't even
      # loaded we cannot be in a reactor — so this is a threaded server and we never
      # touch async. defined? short-circuits before Async::Task is referenced.
      def async_reactor?
        defined?(Async::Task) && Async::Task.current?
      end

      def websocket?(env)
        env["HTTP_UPGRADE"].to_s.casecmp?("websocket") && env["HTTP_SEC_WEBSOCKET_KEY"]
      end

      def upgrade_headers(env)
        accept = [Digest::SHA1.digest("#{env['HTTP_SEC_WEBSOCKET_KEY']}#{WS_GUID}")].pack("m0")
        { "upgrade" => "websocket", "connection" => "Upgrade", "sec-websocket-accept" => accept }
      end

      def upgrade_required
        body = "This endpoint speaks the Terminalwire WebSocket protocol.\n"
        [426, { "content-type" => "text/plain", "connection" => "Upgrade",
                "upgrade" => "websocket", "content-length" => body.bytesize.to_s }, [body]]
      end

      # --- threaded path (Puma): minimal RFC 6455 framing ----------------------

      # Just the framing this needs: encode unmasked server->client binary frames;
      # the Sec-WebSocket-Accept value lives on Rack. One WebSocket message == one
      # MessagePack protocol frame.
      module Frame
        CLOSE = [0x88, 0].pack("C2").freeze

        module_function

        def binary(payload)
          body = payload.b
          n = body.bytesize
          head =
            if    n < 126    then [0x82, n].pack("C2")
            elsif n < 65_536 then [0x82, 126, n].pack("C2n")
            else                  [0x82, 127, n].pack("C2Q>")
            end
          head + body
        end

        def pong(payload) = [0x8A, payload.bytesize].pack("C2") + payload.b
      end

      # Incremental parser: feed raw socket chunks, yield [opcode, payload] per
      # message (reassembling fragments, unmasking — client frames are masked).
      class Parser
        def initialize
          @buf = "".b
          @frag = "".b
          @frag_opcode = nil
        end

        def push(chunk)
          @buf << chunk.b
          while (frame = next_frame)
            fin, opcode, payload = frame
            case opcode
            when 0x0 # continuation
              @frag << payload
              (yield(@frag_opcode, @frag); @frag = "".b; @frag_opcode = nil) if fin
            when 0x1, 0x2 # text / binary
              if fin then yield(opcode, payload) else @frag_opcode = opcode; @frag = payload.b end
            else # control: 0x8 close, 0x9 ping, 0xA pong
              yield(opcode, payload)
            end
          end
        end

        private

        # A non-destructive read cursor over the buffer. Each read either returns
        # the next bytes and advances, or throws :incomplete — meaning a whole frame
        # isn't buffered yet, so we must leave @buf untouched and wait for more. That
        # "consume nothing until the frame is complete" rule is the parser's one
        # sharp edge; the cursor makes it structural instead of a hand-checked guard
        # before every slice.
        class Cursor
          def initialize(buf)
            @buf = buf
            @off = 0
          end

          def byte
            throw :incomplete if @off >= @buf.bytesize
            b = @buf.getbyte(@off)
            @off += 1
            b
          end

          def take(n)
            throw :incomplete if @buf.bytesize < @off + n
            slice = @buf.byteslice(@off, n)
            @off += n
            slice
          end

          # The unconsumed tail — what's left after a frame is committed.
          def rest = @buf.byteslice(@off..) || "".b
        end

        # Decode one frame from @buf, or return nil if a whole frame isn't buffered
        # yet (consuming nothing). Reads top to bottom in RFC 6455 wire order:
        # 2-byte header, optional extended length, optional mask key, then payload.
        # @buf is only advanced (cur.rest) once the full frame is in hand.
        def next_frame
          catch(:incomplete) do
            cur = Cursor.new(@buf)
            b0 = cur.byte
            b1 = cur.byte
            fin    = b0.anybits?(0x80)
            opcode = b0 & 0x0F
            masked = b1.anybits?(0x80)
            len    = b1 & 0x7F
            len = cur.take(2).unpack1("n")  if len == 126
            len = cur.take(8).unpack1("Q>") if len == 127
            key     = cur.take(4).bytes if masked
            payload = cur.take(len).b
            @buf = cur.rest
            unmask!(payload, key) if masked
            return [fin, opcode, payload]
          end
          nil # incomplete frame: need more bytes, @buf left untouched
        end

        def unmask!(payload, key)
          i = 0
          n = payload.bytesize
          while i < n
            payload.setbyte(i, payload.getbyte(i) ^ key[i & 3])
            i += 1
          end
        end
      end

      # The streaming body for a threaded server. #call(stream) gets the raw
      # blocking socket after the 101; it runs the CLI on its own thread and pumps
      # the socket on another, then returns so the web server can reuse the worker.
      class ThreadBridge
        def initialize(handler, host: nil)
          @handler = handler
          @host = host
        end

        # :nocov: blocking-socket threading — exercised live by the conformance suite, not units.
        def call(stream)
          write_lock = Mutex.new
          parser = Parser.new
          transport = Transport::Queue.new(
            # Serialize writes: the client forbids concurrent writes, and the
            # runtime emits from more than one thread.
            sink: ->(bytes) { write_lock.synchronize { stream.write(Frame.binary(bytes)) } }
          )

          cli = Thread.new { @handler.call(transport: transport, host: @host) }

          Thread.new do
            loop do
              parser.push(stream.readpartial(4096)) do |opcode, payload|
                case opcode
                when 0x1, 0x2 then transport.deliver(payload)        # protocol frame
                when 0x9 then write_lock.synchronize { stream.write(Frame.pong(payload)) }
                when 0x8 then raise EOFError                          # client close
                end
              end
            end
          rescue EOFError, IOError, Errno::ECONNRESET, Errno::EPIPE
            # client went away — normal end
          ensure
            transport.close
            cli.join(2)
            write_lock.synchronize { stream.write(Frame::CLOSE) rescue nil }
            stream.close rescue nil
          end
        end
        # :nocov:
      end

      # --- async path (Falcon): bridge async-websocket to the thread runtime ----

      # One WebSocket connection over async-websocket. inbound: connection.read
      # (reactor fiber) -> transport.deliver; outbound: the CLI thread pushes to a
      # Thread::Queue that a writer fiber drains -> connection.
      #
      # The cross-thread hand-off is a plain Thread::Queue, NOT a self-pipe. A fiber
      # blocked in `outbox.pop` yields the reactor, and a `push` from the CLI thread
      # wakes it through the fiber scheduler's own cross-thread wakeup
      # (Async::Scheduler#unblock -> selector.wakeup). We verified this empirically
      # against async 2.39: the reactor keeps running while the writer is parked, and
      # a push from a real OS thread resumes it. An earlier version hand-rolled an
      # IO.pipe to wake the reactor — that just reimplemented selector.wakeup, so it
      # is gone. The CLI runs on a real Thread (not a fiber) on purpose: a user's CLI
      # makes arbitrary blocking calls, which would stall the whole reactor if run as
      # a fiber — Sam's own guidance is to offload blocking work to a thread.
      class ReactorBridge
        JOIN_TIMEOUT = 2

        def initialize(connection, handler, host: nil)
          @connection = connection
          @handler = handler
          @host = host
        end

        # :nocov: reactor-fiber bridge — exercised live by the conformance suite, not units.
        def run
          # Falcon already runs us in a reactor; Sync reuses it (and would create
          # one if absent), giving the connection's fiber I/O a scheduler.
          Sync do |task|
            outbox = ::Queue.new # Thread::Queue: thread-safe + fiber-scheduler aware
            transport = Transport::Queue.new(sink: ->(bytes) { outbox << bytes })

            cli = Thread.new { @handler.call(transport: transport, host: @host) }

            writer = task.async do
              # pop blocks the fiber until the CLI thread pushes (cross-thread wakeup
              # via the scheduler); nil means the outbox was closed in teardown.
              while (bytes = outbox.pop)
                @connection.send_binary(bytes)
                @connection.flush if outbox.empty? # batch: flush once the burst drains
              end
            rescue EOFError, IOError, Errno::EPIPE
              # connection died mid-write
            end

            begin
              while (message = @connection.read)
                transport.deliver(message.buffer.b)
              end
            rescue EOFError, IOError, Errno::ECONNRESET, Errno::EPIPE
              # client disconnected
            end
          ensure
            transport&.close      # unblock the handler's pending reads/requests
            cli&.join(JOIN_TIMEOUT) # let it emit the exit frame (writer drains it meanwhile)
            outbox&.close         # -> writer's pop returns nil -> writer fiber ends
            writer&.wait
          end
        end
        # :nocov:
      end
    end
  end
end
