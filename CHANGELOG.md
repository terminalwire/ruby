# Changelog

All notable changes to Terminalwire are documented here. Format follows
[Keep a Changelog](https://keepachangelog.com/); versions follow the gem's
`Terminalwire::V2::VERSION`.

## [2.0.0.alpha1] — Unreleased

Terminalwire v2 is a ground-up rewrite of the protocol and client. v1 streamed a
Ruby CLI from a server to a thin Tebako-packaged Ruby client; v2 keeps that idea
but replaces the wire, the client, and the trust model — and runs **side by side
with v1 over the same endpoint** so existing apps keep working unchanged.

### The shape of the change

- **One WebSocket, sans-IO protocol core, MessagePack wire.** The protocol is
  specified independently of any runtime and pinned by a language-neutral
  conformance corpus, so the Ruby server, the Go client, and the Elixir server
  stay in lockstep.
- **Evergreen Go client.** The client is a single static Go binary (replacing the
  Tebako Ruby runtime) that ships, signs, and updates itself — see *Distribution*.

### Added

- **`Terminalwire::V2`** — the v2 server runtime: group-leader IO over the wire
  (stdout/stderr/stdin), credit-based **flow control** (chunked writes with
  backpressure so a fast server can't outrun a slow client), **live terminal
  resize**, **raw input** streaming (the foundation for REPLs/TUIs), **stdin
  piping**, `interrupt` → exit 130, and a terminal-capabilities handshake so
  server-side TUI libraries can negotiate features without a full PTY.
- **`Terminalwire::V2::Server.dualize(ThorClass)`** — walks a Thor class and its
  subcommand tree and extends each to answer over **both** the v1 and v2 wire.
  One CLI definition, both protocols; the exec launcher's `url:` never changes.
- **Consent / entitlement model.** The client is the trust boundary. Storage and
  grants are keyed on the RFC 6454 **origin** (scheme+host+port); a hand-editable
  per-origin YAML policy governs env vars, paths (with modes), and which domains a
  server may open in a browser (**same-authority by default**, anti-phishing).
  Control files (the policy/origin markers) can never be granted to a server.
- **Signed self-update trust chain.** Offline root key → delegated release-key
  cert → release key signs a per-channel manifest → SHA-256-pinned artifact
  (Ed25519, stdlib). The updater is best-effort and never disrupts a session;
  dormant when no roots are embedded. Update channel is **vendor-signed only** —
  never a connected server.
- **Versioning model.** Additive *capabilities* vs rare *protocol-version* breaks,
  negotiated by range overlap in the `hello` handshake; the client carries
  backward-compat, the server feature-detects.
- **`directory.ls`** alias on the v2 context (rides the existing `directory.list`
  op) so v1-era command code that calls `client.directory.ls` runs unchanged.

### Compatibility

- **v1 and v2 coexist over the same `/terminal` endpoint**, distinguished by the
  `terminalwire.v2` WebSocket subprotocol. v1 code is byte-for-byte unchanged; the
  only v1-gem touch on this line was an additive `Context#warn`.
- v2 ships as the gem **`terminalwire`** (`Terminalwire::V2`); the v1 runtime stays
  on `terminalwire-core` / `-client` / `-server` / `-rails`. Different namespaces,
  no file overlap — they install together. There is no v1→v2 compat shim by design.

### Performance

Measured against the v1 Tebako client, same server, same command, over localhost:

- **Per command: ~50–68× faster** (~16 ms vs ~860 ms). v1 pays a full Ruby-VM boot
  on every invocation; the Go client does not. This is the dominant win for
  interactive use and for running many commands.
- **Large-file transfer: ~6–12× faster** steady-state (pure transport, startup
  subtracted), up to ~30× end-to-end. v2's chunked, flow-controlled streaming is
  flat-fast from the first byte; v1's throughput only climbs as its fixed startup
  amortizes over a larger payload.

[2.0.0.alpha1]: https://github.com/terminalwire/ruby/tree/main
