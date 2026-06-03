# Terminalwire — Ruby server (v2)

This is the **open-source Ruby server runtime** for Terminalwire v2. It lets a
Ruby/Rails app expose a CLI that streams terminal I/O to the Terminalwire client
over a single multiplexed WebSocket — no web API required.

It is one implementation of the Terminalwire v2 protocol; more servers are
planned (Elixir next). The protocol spec, conformance suite, and the proprietary
client live in separate repositories:

- **Protocol spec + conformance suite** — `terminalwire/protocol` (private)
- **Client** — `terminalwire/cli` (private, proprietary)

## What's here

```
v2/ruby/                     the `terminalwire-v2` gem (open server runtime)
  lib/terminalwire/v2/
    codec / negotiator / frames / mux / window   sans-IO protocol core
    server/                  Connection, Runtime, Context, Handler, Session,
                             Terminal, Flow, Thor integration
    transport/               Memory + Queue transports (bridge to your WebSocket)
```

The repository root also contains the **v1** gems (`gem/…`), still published and
maintained.

## Wiring a Rails (or any Rack) server

`Terminalwire::V2::Server::Handler` runs a Thor CLI over any transport;
`Server::Session` bridges a callback/event-loop WebSocket (ActionCable, async):

```ruby
class MyCLI < Thor
  include Terminalwire::V2::Server::Thor

  desc "deploy", "deploy the app"
  def deploy
    say "Deploying for #{ask('environment?')}…"
  end
end

# In an ActionCable channel (binary frames):
def subscribed
  @session = Terminalwire::V2::Server::Session.start(
    cli_class: MyCLI,
    on_send:   ->(bytes) { transmit_binary(bytes) }
  )
end
def receive(bytes) = @session.receive(bytes)
def unsubscribed   = @session&.close
```

## Capabilities

The server negotiates capabilities with the client at handshake and uses only
the intersection: `stdio file directory browser env signal flow raw-input
terminal-query`. Output is flow-controlled; input supports line/secret/single-key
(cbreak)/bulk-pipe/raw-stream; terminal size, resize, and interrupt are handled.

## Testing

The conformance suite (which validates this server against the language-neutral
corpus) lives in `terminalwire/protocol`. To run it against this gem, check out
both repos and point `TERMINALWIRE_CORPUS` at the protocol repo's `conformance/`
directory. This repo ships the server runtime; the protocol repo ships the tests.

## License

Source-available (not AGPL) — intended to be safe for companies to install on
their own servers. See `LICENSE.txt`.
