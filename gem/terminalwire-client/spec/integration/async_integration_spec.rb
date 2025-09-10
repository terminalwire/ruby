require "spec_helper"
require "async"
require "securerandom"
require "stringio"
require "fileutils"
require "tmpdir"

RSpec.describe "Terminalwire async integration" do
  class MemoryTransport < Terminalwire::Transport::Base
    def self.pair
      a_in = Async::Queue.new
      b_in = Async::Queue.new
      a = new(a_in, b_in)
      b = new(b_in, a_in)
      [a, b]
    end

    def initialize(in_q, out_q)
      @in_q = in_q
      @out_q = out_q
      @closed = false
    end

    def read
      return nil if @closed
      @in_q.dequeue
    end

    def write(data)
      return if @closed
      @out_q.enqueue(data)
    end

    def close
      return if @closed
      @closed = true
      @in_q.enqueue(nil) rescue nil
      @out_q.enqueue(nil) rescue nil
    end
  end

  # Minimal endpoint stub to satisfy Handler.initialize
  EndpointStub = Struct.new(:authority) do
    def to_url
      "ws://#{authority}"
    end
  end

  around do |example|
    Async do |task|
      # Capture stdio for the client resources.
      orig_out, orig_err = $stdout, $stderr
      begin
        @stdout_io = StringIO.new
        @stderr_io = StringIO.new
        $stdout = @stdout_io
        $stderr = @stderr_io

        # Make client storage sandboxed
        original_home = ENV["TERMINALWIRE_HOME"]
        ENV["TERMINALWIRE_HOME"] = Dir.mktmpdir

        example.run
      ensure
        $stdout = orig_out
        $stderr = orig_err
        # Cleanup temp storage
        if ENV["TERMINALWIRE_HOME"] && Dir.exist?(ENV["TERMINALWIRE_HOME"])
          FileUtils.rm_rf(ENV["TERMINALWIRE_HOME"])
        end
        ENV["TERMINALWIRE_HOME"] = original_home
      end
    end
  end

  def setup_client_and_server
    # Create in-memory transports and adapters
    server_transport, client_transport = MemoryTransport.pair
    server_adapter = Terminalwire::Adapter::Socket.new(server_transport)
    client_adapter = Terminalwire::Adapter::Socket.new(client_transport)

    # Start client handler inside Async reactor
    endpoint = EndpointStub.new("example.test")
    client_handler = Terminalwire::Client::Handler.new(client_adapter, endpoint:)
    client_task = Async::Task.current.async do
      client_handler.connect
    end

    # Build server session and background ingest loop.
    session = Terminalwire::Server::Session.new(server_adapter)

    init_condition = Async::Condition.new
    init_message = nil

    Async::Task.current.async do
      while (msg = server_adapter.read)
        # Route responses for in-flight requests first.
        handled = session.ingest(msg)
        next if handled

        case msg
        in { event: "initialization", protocol:, program:, entitlement: }
          init_message ||= msg
          init_condition.signal
        else
          # Ignore other messages at this level.
        end
      end
    end

    # Wait for initialization from client.
    Async::Clock.timeout(5) { init_condition.wait }

    # Build server context with entitlement provided by client.
    context = Terminalwire::Server::Context.new(adapter: server_adapter, entitlement: init_message[:entitlement])

    [context, session, client_task, server_adapter, client_adapter]
  end

  it "handles 10k STDOUT puts quickly using notifications" do
    context, _session, client_task, server_adapter, client_adapter = setup_client_and_server

    expected = 10_000
    start = Async::Clock.monotonic

    # Blast notifications (fire-and-forget).
    expected.times do |i|
      context.stdout.puts("hello #{i}")
    end

    # Wait for client to consume and print all lines.
    Async::Clock.timeout(5) do
      loop do
        break if @stdout_io.string.count("\n") >= expected
        Async::Clock.sleep(0.01)
      end
    end

    elapsed = Async::Clock.monotonic - start

    # Sanity: verify the count and timing. Threshold is generous to be CI-safe.
    expect(@stdout_io.string.count("\n")).to eq(expected)
    expect(elapsed).to be < 2.0

    # Cleanup
    client_task.stop
    server_adapter.close
    client_adapter.close
  end

  it "pipelines many file operations concurrently and returns correct results" do
    context, _session, client_task, server_adapter, client_adapter = setup_client_and_server

    # Prepare N files with concurrent writes:
    n = 200
    base = context.storage_path # derived by server context from client env
    paths = Array.new(n) { |i| base.join("async_file_#{i}.txt").to_s }

    write_barrier = Async::Barrier.new
    n.times do |i|
      write_barrier.async do
        context.file.write(paths[i], "data-#{i}")
      end
    end
    write_barrier.wait

    # Concurrent reads
    read_barrier = Async::Barrier.new
    results = Array.new(n)
    n.times do |i|
      read_barrier.async do
        results[i] = context.file.read(paths[i])
      end
    end
    read_barrier.wait

    # Validate
    expect(results).to eq(Array.new(n) { |i| "data-#{i}" })

    # Cleanup
    client_task.stop
    server_adapter.close
    client_adapter.close
  end
end