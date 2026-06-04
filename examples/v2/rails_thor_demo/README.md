# Terminalwire Thor demo (v2)

A one-page Rails app that serves a [Thor](https://github.com/rails/thor) CLI over
Terminalwire — you run it on the server, but its prompts, output, colors, tables,
and file access all happen on **your** terminal.

## Run it

```sh
cd examples/v2/rails_thor_demo
bundle install

# Works on either server:
bundle exec puma config.ru -p 3000      # threaded (what most people deploy)
# or
bundle exec falcon serve --bind http://127.0.0.1:3000   # async
```

Then drive it from your terminal with the Terminalwire client:

```sh
terminalwire ws://localhost:3000/terminal hello
terminalwire ws://localhost:3000/terminal table     # a tty-table sized to your terminal
terminalwire ws://localhost:3000/terminal sysinfo   # what the server sees about you
terminalwire ws://localhost:3000/terminal survey    # ask / yes? / hidden password
terminalwire ws://localhost:3000/terminal login     # writes a token into your origin's sandbox
terminalwire ws://localhost:3000/terminal whoami    # reads it back
terminalwire ws://localhost:3000/terminal logout
```

(During development the client binary lives at `/tmp/terminalwire`.)

## What's in `app.rb`

The whole integration is two things:

```ruby
class DemoCLI < Thor
  include Terminalwire::V2::Server::Thor   # reroutes puts/ask/yes?/say to the client
  # ...commands...
end

# config/routes.rb
mount Terminalwire::V2::Server::Rack.new(DemoCLI), at: "/terminal"
```

That `mount` is the entire server-side integration. `Terminalwire::V2::Server::Rack`
owns the WebSocket upgrade, the framing, and the per-connection threading, and it
runs on both threaded servers (Puma) and async servers (Falcon) — it picks the
right strategy per request, so your app code is identical either way.

## How it spans both servers

The v2 server runtime is thread-based, so the adapter meets each server where it
lives (detected via `Async::Task.current?`):

- **Puma / threaded** — a raw RFC 6455 upgrade whose streaming body does the
  framing on plain blocking socket I/O in threads. No async reactor, so nothing
  fights Puma's socket write-timeout watchdog.
- **Falcon / async** — `async-websocket` drives the connection in reactor fibers,
  bridged to the runtime's threads with a queue and a wake pipe.

Both paths live inside the gem (`terminalwire/v2/server/rack.rb`); the host app
never sees a thread, a fiber, or a pipe.
