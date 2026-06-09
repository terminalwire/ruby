# Terminalwire: v1 → v2 → beyond

A **runnable** guide to the v1→v2 transition. Every command here is copy-pasteable
against a running Terminalwire server; the output blocks are real.

The whole transition rests on one invariant: **one URL, two wire protocols.** A v1
client and a v2 client connect to the same `/terminal` endpoint with the same
launcher `url:` — they're told apart by the WebSocket subprotocol, not the address.
So you roll out v2 with zero disruption to v1 users, and remove v1 later without
anyone re-pointing anything.

---

## 0. Set up (to follow along)

**A running server.** Locally, boot the Rails app in development:

```sh
cd ~/Projects/terminalwire/server
bin/rails server -p 3009        # Falcon; leave it running
```

(Or use production: `wss://terminalwire.com/terminal` — same commands, swap the URL.)

**Both clients.**

```sh
# v1 — the Tebako Ruby client you already have installed:
ls ~/.terminalwire/bin/terminalwire-exec          # ~26 MB, bundles a Ruby VM

# v2 — build the static Go client from terminalwire/cli (fresh clone; a stale
# /tmp checkout can be missing files):
gh repo clone terminalwire/cli /tmp/cli && cd /tmp/cli
go build -buildvcs=false -o /tmp/tw/terminalwire-exec ./cmd/terminalwire-exec
go build -buildvcs=false -o /tmp/tw/terminalwire      ./cmd/terminalwire   # sibling, on PATH
```

**One launcher stub both clients share** — the `url:` never changes between v1 and v2:

```sh
printf '#!/usr/bin/env terminalwire-exec\nurl: "ws://localhost:3009/terminal"\n' > /tmp/tw/app
chmod +x /tmp/tw/app
cat /tmp/tw/app
# #!/usr/bin/env terminalwire-exec
# url: "ws://localhost:3009/terminal"
```

---

## 1. How v1 works (the old way)

v1 streams a server-side **Ruby** CLI (a `Thor` class, `MainTerminal`) down to a thin
**Tebako-packaged Ruby** client. The client is a ~26 MB binary that boots an entire
Ruby VM on every invocation; the server drives the client's stdout/stdin/filesystem
over the wire.

Run a command against the server with the v1 client:

```sh
~/.terminalwire/bin/terminalwire-exec /tmp/tw/app help
```
```
Commands:
  terminalwire apps                                   # List apps installed i...
  terminalwire distribution                           # Publish & manage dist...
  terminalwire help [COMMAND]                          # Describe available co...
  terminalwire install APP                             # Install a terminalwire app
  ...
```

```sh
~/.terminalwire/bin/terminalwire-exec /tmp/tw/app tree
```
```
main_terminal
  ├─ apps (List apps installed in terminalwire directory)
  ├─ distribution (Publish & manage distributions)
  ├─ install (Install a terminalwire app)
  ├─ license (Provision & manage licenses)
  ...
```

That works, and it's what's in production today. The cost: every command pays the
full Ruby-VM boot, and the client is a heavy platform-specific Tebako build.

---

## 2. How v2 works

v2 keeps the exact same idea — server-side CLI, thin client — but replaces the wire
(sans-IO core, MessagePack, flow-controlled streaming, raw input for REPLs/TUIs) and
the client (a single static **Go** binary that ships and updates itself).

Point the **v2** client at the **same stub, same server**:

```sh
PATH=/tmp/tw:$PATH /tmp/tw/terminalwire-exec /tmp/tw/app help
PATH=/tmp/tw:$PATH /tmp/tw/terminalwire-exec /tmp/tw/app tree
PATH=/tmp/tw:$PATH /tmp/tw/terminalwire-exec /tmp/tw/app apps
```

The output is **identical** to v1 — it's the same `MainTerminal`, served over both
wires by `dualize` (one Thor class, both protocols). For example `apps`:

```
┌────────────┬──────────────────────────────────────────────────┐
│Name        │Super fun                                         │
│Installation│terminalwire install seemed                       │
│URL         │https://localhost:5400/developer/license/pro/new  │
└────────────┴──────────────────────────────────────────────────┘
```

### Proof it's the subprotocol, not the URL

```sh
# v2 client advertises Sec-WebSocket-Protocol: terminalwire.v2  -> v2 server
# no/other subprotocol                                          -> unchanged v1 handler
```

### Why v2 is better (measured, same server, same command)

Run the built-in benchmark (dev-only command; see `server/script/benchmark.py`):

```sh
PATH=/tmp/tw:$PATH STUB=/tmp/tw/app V2=/tmp/tw/terminalwire-exec \
  ~/Projects/terminalwire/server/script/benchmark.py --noop 30 --sizes 10,50,100
```

| Dimension | v1 (Tebako) | v2 (Go) | v2 win |
|-----------|-------------|---------|--------|
| Per command (running lots of commands, interactive launch) | ~860 ms | ~16 ms | **~50–68×** |
| Large-file transfer, end-to-end | ~46 MB/s | ~520 MB/s | **~12×** |
| Large-file transfer, steady-state (startup subtracted) | — | — | **~6–12×** |

Plus capabilities v1 doesn't have at all: raw-input streaming (REPLs/TUIs), live
terminal resize, credit-based flow control, and a self-updating client.

### One difference worth knowing

In v2, **`setup` and `install` run client-side, in the Go binary** (`terminalwire
setup`, `terminalwire install <app> <url>`) — the thin client does its own local
filesystem work. In v1 those ran server-side, driving the client's filesystem over
the wire. So the server-side `MainTerminal` `setup`/`install` commands are a v1
flow; v2 apps install locally. Everything else (your app's own commands, I/O,
prompts, `apps`, `tree`, `help`) runs the same over both.

---

## 3. Deploy the transitional setup (v1 + v2 side by side)

This is the whole rollout, and it's packaged in the v2 gem so **every** Terminalwire
server gets it the same way: a git ref + one route line.

**Gemfile** — add the v2 gem alongside your existing v1 gems (git ref only; this is
transitional):

```ruby
# Your existing v1 gems stay exactly as they are (terminalwire-core/-client/
# -server/-rails). Add the v2 gem from a git ref:
gem "terminalwire",
  git: "https://github.com/terminalwire/ruby",
  branch: "main",
  glob: "v2/ruby/*.gemspec",
  require: false            # loaded explicitly in routes.rb
```

```sh
bundle install
```

**config/routes.rb** — change exactly one line. Your v1 mount was:

```ruby
match "/terminal",
  to: Terminalwire::Rails::Thor.new(MainTerminal),   # v1 only
  via: [:get, :connect]
```

Swap it for the dual dispatcher:

```ruby
require "terminalwire/v2/rails"

match "/terminal",
  to: Terminalwire::V2::Rails.dual_terminal(MainTerminal),  # v1 AND v2
  via: [:get, :connect]
```

That's it. `dual_terminal` dualizes your CLI and routes each connection by its
advertised subprotocol — v2 clients get the v2 server, everyone else gets the
unchanged v1 handler. **Deploy normally.** Existing v1 users notice nothing; v2
clients pointed at the same URL now get v2.

> For a v2-only app (no v1 gems), skip `dual_terminal` and mount the v2 server
> directly: `mount Terminalwire::V2::Server::Rack.new(MainTerminal), at: "/terminal"`.

**Verify after deploy** (against your real server, swapping the URL in the stub):

```sh
~/.terminalwire/bin/terminalwire-exec /tmp/tw/app help   # v1 still works
PATH=/tmp/tw:$PATH /tmp/tw/terminalwire-exec /tmp/tw/app help  # v2 works, same URL
```

---

## 4. Remove v1 (when you're ready)

Once your clients have moved to v2, drop v1 in three edits — and again, **the
launcher `url:` never changes**, so no client re-points.

**Gemfile** — remove the v1 sub-gems, keep the v2 gem:

```ruby
# delete: terminalwire-core / -client / -server / -rails
gem "terminalwire", git: "https://github.com/terminalwire/ruby", branch: "main",
  glob: "v2/ruby/*.gemspec"
```

**config/routes.rb** — replace the dual dispatcher with a direct v2 mount:

```ruby
require "terminalwire/v2/server/rack"

mount Terminalwire::V2::Server::Rack.new(MainTerminal), at: "/terminal"
```

**Cleanup** — remove any v1-only install routing (the `X-Version` divert and the
`bash/v2` vs `bash` install controllers collapse to a single v2 install path).

```sh
bundle install && bundle exec rspec   # confirm green
```

Now the server speaks only v2; v1 clients that haven't updated will fail to
negotiate (expected), everyone on v2 keeps working at the same URL.

---

## Verify-everything checklist

Against a running server (local `:3009` or prod), with the stub from §0:

- [ ] `~/.terminalwire/bin/terminalwire-exec /tmp/tw/app help` → v1 renders the CLI
- [ ] `PATH=/tmp/tw:$PATH /tmp/tw/terminalwire-exec /tmp/tw/app help` → v2 renders the same CLI
- [ ] `… /tmp/tw/app tree` and `… apps` → identical output on both clients
- [ ] benchmark shows v2 faster per-command and per-byte (§2)
- [ ] after the §3 edits: both clients work against the **same** deployed URL
- [ ] `bundle exec rspec spec/requests/bash spec/lib/terminalwire` → green
      (dispatch, dualize, and the install-script injection regression)

See also: `CHANGELOG.md` (what v2 is), `server/V2_SELF_HOSTING.md` (the dispatch
internals + local reproduce recipe).
