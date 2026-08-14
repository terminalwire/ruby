# frozen_string_literal: true

# Regression: a command that calls `exit`/`abort` raises SystemExit, which is NOT
# a StandardError. Before the fix it slipped past the Handler's rescue, the ensure
# reported `exit(0)` to the client (success!), and the exception then silently
# killed the CLI thread. The client must be told the real exit code.
require "terminalwire/v2"
require "terminalwire/v2/server/rack" # Transport::Queue lives under the server tree

RSpec.describe "Terminalwire::V2::Server::Handler exit status" do
  # Drive a full session: deliver a hello, run `body`, and return the status the
  # server reported to the client in its exit frame.
  def run_session(&body)
    sent = []
    transport = Terminalwire::V2::Transport::Queue.new(sink: ->(bytes) { sent << bytes })

    hello = Terminalwire::V2::Frames.hello(
      protocol: Terminalwire::V2::Protocol::MAX_VERSION,
      capabilities: Terminalwire::V2::Protocol::CAPABILITIES,
      program: { "name" => "demo", "args" => [] },
      entitlement: { "paths" => [{ "glob" => "/tmp/terminalwire-test/**" }] }
    )
    transport.deliver(Terminalwire::V2::Codec.encode(hello))

    handler = Terminalwire::V2::Server::Handler.new(run: ->(_ctx, _args) { body.call })
    thread = Thread.new { handler.call(transport: transport) }
    status = thread.value

    exit_frame = sent.map { |b| Terminalwire::V2::Codec.decode(b) }
                     .find { |f| f["t"] == Terminalwire::V2::Protocol::Type::EXIT }
    [status, exit_frame && exit_frame["status"]]
  end

  it "reports a nonzero code from exit(n) to the client, not 0" do
    status, client_status = run_session { exit 3 }
    expect(status).to eq 3
    expect(client_status).to eq 3
  end

  it "reports 1 from abort" do
    _status, client_status = run_session { abort "nope" }
    expect(client_status).to eq 1
  end

  it "still reports 0 for a clean exit" do
    _status, client_status = run_session { exit 0 }
    expect(client_status).to eq 0
  end

  it "reports 0 for a command that just returns" do
    _status, client_status = run_session { :ok }
    expect(client_status).to eq 0
  end
end
