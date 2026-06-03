# Terminalwire for Ruby & Rails

**Ship a CLI for your web app. No API required.**

Terminalwire streams a command-line app straight from your server. Instead of
building a REST/GraphQL API, generating an SDK, and maintaining a separately
released client, you write your CLI *in your Rails app* — and it runs on your
users' machines over a single WebSocket.

```ruby
# app/terminal/main_terminal.rb
class MainTerminal < ApplicationTerminal
  desc "deploy", "Deploy the app"
  def deploy
    puts "Deploying #{current_user.app} to production…"
    # ...your real app code: models, jobs, mailers, the works
    puts "Done. ✅"
  end
end
```

Your user runs `your-app deploy` and the command executes **on your server**,
with full access to your database, models, and business logic — while their
terminal, files, and browser stay on *their* machine.

## Why this is nice

- **No API to build or version.** Your CLI calls your app's code directly. No
  serializers, no SDK, no client/server version skew to manage.
- **It feels local.** Output streams in real time, prompts and passwords work,
  and it's color/TTY-aware. Your server runs the command; the user's terminal
  renders it.
- **Secure by construction.** The client is the trust boundary: the server
  *requests* access to a file, an env var, or the browser, and the client
  enforces a per-app entitlement policy. Your server never touches the user's
  machine directly.
- **Auth is just your app's auth.** Sessions, current-user, and permissions are
  whatever your Rails app already does.

The **v2** protocol (the `terminalwire` gem under [`v2/`](v2/README.md)) adds a
lot more — use *any* CLI library (Thor, Ruby's `OptionParser`, or bare
`$stdin`/`$stdout`), output flow control, window resize, `Ctrl-C` to the
server-side command, piping (`cat data.csv | your-app import`), and raw/
interactive input. The Rails integration for v2 is in progress; the shipping
Rails installer today uses the v1 (Thor) runtime.

## Install (Rails)

Add the gem and run the installer:

```ruby
# Gemfile
gem "terminalwire-rails"
```

```sh
bundle install
rails generate terminalwire:install my-app   # "my-app" is the launcher name
```

That generates `bin/my-app` (the launcher your users run), your CLI in
`app/terminal/main_terminal.rb`, and a `/terminal` route. Edit the CLI, and your
users get the new behavior immediately — there's no client to re-release.

Your users install the client once:

```sh
curl -sSL https://terminalwire.sh | bash
```

## How it works

```
 your users' machine            your Rails server
 ┌────────────────┐   one WS    ┌─────────────────────────────┐
 │ terminalwire    │ ◀────────▶ │ ActionCable / Rack endpoint  │
 │ client (their   │            │   → your Thor (v1) / any-CLI │
 │ terminal, files)│            │     (v2) command, your app   │
 └────────────────┘            └─────────────────────────────┘
```

The client is a small, fast binary on the user's workstation. Your server runs
the CLI and streams terminal I/O — stdout/stderr, prompts, files, the browser —
over the wire. (The richer I/O modes — flow control, piping, raw/interactive
input — are part of the v2 protocol; see [`v2/`](v2/README.md).)

## What's in this repository

- **`v2/ruby/`** — the modern (v2) open-source server runtime, the `terminalwire`
  gem. This is where active development happens. See the
  [v2 README](v2/README.md) for wiring details (Rails/ActionCable, Rack, Thor,
  OptionParser).
- **`gem/`** — the v1 gems (`terminalwire`, `terminalwire-rails`, …), still
  published and maintained.

There are servers for other languages too — e.g. [Elixir](https://github.com/terminalwire/elixir).
They all speak the same wire protocol and interoperate with the same client.

## Documentation

- Rails guide: https://terminalwire.com/docs/rails
- Client manual: https://terminalwire.com/docs/client

## License

Source-available. Free for personal use and small/early-stage businesses;
commercial use is licensed — see `LICENSE.txt` or https://terminalwire.com/license.

## Contributing

Bug reports and pull requests are welcome at
https://github.com/terminalwire/ruby. Please follow the
[code of conduct](CODE_OF_CONDUCT.md).
