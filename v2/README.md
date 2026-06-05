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
v2/ruby/                     the `terminalwire` gem (open server runtime)
  lib/terminalwire/v2/
    codec / negotiator / frames / mux / window   sans-IO protocol core
    server/                  Connection, Runtime, Context, Handler, Session,
                             Terminal, Flow, Thor integration
    transport/               Memory + Queue transports (bridge to your WebSocket)
```

The repository root also contains the **v1** gems (`gem/…`), still published and
maintained.

## Wiring a Rails (or any Rack) server

Write an ordinary Thor CLI and `include Terminalwire::V2::Server::Thor` — that
reroutes its I/O (`puts`/`ask`/`yes?`/password, and any `tty-*` / `pastel` output)
to the connected client's terminal:

```ruby
class MyCLI < Thor
  include Terminalwire::V2::Server::Thor

  desc "deploy", "deploy the app"
  def deploy
    say "Deploying for #{ask('environment?')}…"
  end
end
```

Then mount the WebSocket endpoint — one line, the whole integration:

```ruby
require "terminalwire/v2/server/rack"

# config/routes.rb (or any Rack app)
mount Terminalwire::V2::Server::Rack.new(MyCLI), at: "/terminal"
```

`Server::Rack` speaks the Rack 3 streaming protocol, so the same line runs on
**Puma** (threaded) and **Falcon** (async) — it picks the right strategy per
request and owns the WebSocket upgrade, framing, and per-connection threading
internally. (`Server::Handler` + the `Transport::Memory`/`Transport::Queue`
transports are the lower-level seams if you're bridging a different server,
e.g. an ActionCable channel.)

### Server-side TTY libraries, dropped in

Run `Server.install!` once before loading your TTY libs, then wrap a command body
in `Server.redirect(context)` and unmodified `tty-table` / `tty-box` / `pastel` /
… render on the *client's* terminal — they auto-detect its color and width
(`Pastel.new`, `TTY::Screen.width`) because `$stdout` points at the client. See
`examples/v2/rails_thor_demo` for a runnable showcase (table, prompts, resize).

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
