# Terminalwire v2

Clean-sheet rewrite. A **Go thin client** streams terminal I/O to a **Ruby/Rails
server** over a single multiplexed WebSocket, with the protocol pinned by a
**language-neutral conformance corpus** that both sides run. No v1 compatibility.

See the [GitHub epic #11](https://github.com/terminalwire/ruby/issues/11) for the
full plan.

## Why v2

- **Go client** — Tebako (which packaged the v1 Ruby client) is unmaintained. Go
  cross-compiles to a single static binary per platform (~7 MB), trivial to
  distribute, with goroutines that fit a multiplexed protocol.
- **Multiplexed, one-way output** — one WebSocket, every frame tagged with a
  `sid`; stdout/stderr stream one-way with no per-write ack (the v1 latency sink).
- **Conformance-harness-first** — the protocol is sans-IO and validated by a
  shared corpus, so the Go client and any server implementation are provably
  interoperable.

## Layout

```
PROTOCOL.md         the wire contract (multiplexed framing, handshake, errors)
conformance/        language-neutral test corpus — the executable spec
  vectors/          negotiate · roundtrip · golden · validate
ruby/               sans-IO core + server runtime (gem: terminalwire2)
  lib/terminalwire2/  codec, negotiator, frames, mux, server/*, transport/*
  spec/             RSpec runner that drives the corpus + unit/integration tests
go/                 Go client (module: github.com/terminalwire/client)
  protocol/         sans-IO core mirroring Ruby, runs the SAME corpus
  entitlement/      client-side trust boundary (doublestar globbing)
  client/           connection + resources (stdin/file/dir/browser/env)
  transport/        WebSocket transport (gorilla)
  cmd/terminalwire/ the client binary
```

## Status

Verified green:

| Component            | Tests                          | Coverage          |
|----------------------|--------------------------------|-------------------|
| Ruby core + server   | 89 examples, 0 failures        | 99.5% line / 88% branch |
| Go `protocol`        | corpus + units                 | 92.9% statements  |
| Go `entitlement`     | units                          | 100% statements   |
| Go `client`          | units + end-to-end             | 85.6% statements  |

The conformance corpus (negotiate, roundtrip, golden msgpack bytes, malformed
validation) passes in **both** languages — the cross-implementation contract.

## Running the tests

```sh
# Ruby
cd ruby && bundle install && bundle exec rspec

# Go
cd go && go test ./...
```

Each side runs the same `../conformance` vectors via a native runner.

## Building the client

```sh
cd go && go build -o terminalwire ./cmd/terminalwire
./terminalwire wss://your-app.example.com/terminal deploy --force
```

## Wiring a Rails (or any Rack) server

The server is framework-agnostic: `Terminalwire2::Server::Handler` runs a Thor CLI
over any transport. For a callback/event-loop websocket (ActionCable, async),
`Server::Session` bridges it:

```ruby
class MyCLI < Thor
  include Terminalwire2::Server::Thor

  desc "deploy", "deploy the app"
  def deploy
    say "Deploying for #{ask('environment?')}…"
  end
end

# In an ActionCable channel (transmit/receive binary frames):
def subscribed
  @session = Terminalwire2::Server::Session.start(
    cli_class: MyCLI,
    on_send:   ->(bytes) { transmit_binary(bytes) }
  )
end
def receive(bytes) = @session.receive(bytes)
def unsubscribed   = @session&.close
```

## What's next

Tracked under the epic:

- **#16 consent-based entitlements** — server declares needed grants, client
  prompts the user once (today the client uses a conservative default policy).
- **#21 interop matrix CI** — run the Go client against the Ruby server in CI
  (the corpus already guarantees codec/handshake agreement).
- **#17 distribution** — GoReleaser, Homebrew/Scoop, signing, self-update.
- **#20/#22 closed exhaustive harness** — adversarial/fuzz/security tier.
