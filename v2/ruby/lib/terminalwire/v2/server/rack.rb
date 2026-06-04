# frozen_string_literal: true

require "digest"
require "async"                          # Async::Task / Sync (reactor detection + Falcon path)
require "async/websocket/adapters/rack"
require_relative "handler"
require_relative "../transport/queue"

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
    # Opt-in require — it pulls in async-websocket: require "terminalwire/v2/server/rack".
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

        if Async::Task.current?
          # Async server (Falcon): let async-websocket own the connection.
          Async::WebSocket::Adapters::Rack.open(env) { |connection| ReactorBridge.new(connection, @handler).run }
        else
          # Threaded server (Puma & friends): hand-roll the upgrade and stream.
          [101, upgrade_headers(env), ThreadBridge.new(@handler)]
        end
      end

      private

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

        def next_frame
          return nil if @buf.bytesize < 2
          b0 = @buf.getbyte(0)
          b1 = @buf.getbyte(1)
          fin = (b0 & 0x80) != 0
          opcode = b0 & 0x0F
          masked = (b1 & 0x80) != 0
          len = b1 & 0x7F
          off = 2
          if len == 126
            return nil if @buf.bytesize < off + 2
            len = @buf.byteslice(off, 2).unpack1("n"); off += 2
          elsif len == 127
            return nil if @buf.bytesize < off + 8
            len = @buf.byteslice(off, 8).unpack1("Q>"); off += 8
          end
          if masked
            return nil if @buf.bytesize < off + 4
            key = @buf.byteslice(off, 4).bytes; off += 4
          end
          return nil if @buf.bytesize < off + len
          payload = @buf.byteslice(off, len).b
          @buf = @buf.byteslice(off + len..) || "".b
          unmask!(payload, key) if masked
          [fin, opcode, payload]
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
        def initialize(handler)
          @handler = handler
        end

        def call(stream)
          write_lock = Mutex.new
          parser = Parser.new
          transport = Transport::Queue.new(
            # Serialize writes: the client forbids concurrent writes, and the
            # runtime emits from more than one thread.
            sink: ->(bytes) { write_lock.synchronize { stream.write(Frame.binary(bytes)) } }
          )

          cli = Thread.new { @handler.call(transport: transport) }

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
      end

      # --- async path (Falcon): bridge async-websocket to the thread runtime ----

      # One WebSocket connection over async-websocket. inbound: connection.read
      # (reactor fiber) -> transport.deliver; outbound: runtime threads -> queue +
      # a wake pipe -> writer fiber -> connection.
      class ReactorBridge
        JOIN_TIMEOUT = 2

        def initialize(connection, handler)
          @connection = connection
          @handler = handler
        end

        def run
          # Falcon already runs us in a reactor; Sync reuses it (and would create
          # one if absent), giving the connection's fiber I/O a scheduler.
          Sync do |task|
            outbox = ::Queue.new
            wake_read, wake_write = IO.pipe
            transport = Transport::Queue.new(
              sink: ->(bytes) { outbox << bytes; wake_write.write(".") rescue nil }
            )

            cli = Thread.new { @handler.call(transport: transport) }

            writer = task.async do
              loop do
                wake_read.readpartial(4096)
                @connection.send_binary(outbox.pop) until outbox.empty?
                @connection.flush
              end
            rescue EOFError, IOError, Errno::EPIPE
              # pipe closed during teardown
            end

            begin
              while (message = @connection.read)
                transport.deliver(message.buffer.b)
              end
            rescue EOFError, IOError, Errno::ECONNRESET, Errno::EPIPE
              # client disconnected
            end
          ensure
            transport&.close
            cli&.join(JOIN_TIMEOUT)
            wake_write&.close rescue nil
            writer&.wait rescue nil
            wake_read&.close rescue nil
          end
        end
      end
    end
  end
end
