# Releasing the Ruby gems

This repo holds two generations of gems with different release states. See the
workspace `RELEASING.md` in `terminalwire/protocol` for the cross-repo picture.

## Pre-flight

Test against the conformance corpus from the workspace (`terminalwire/protocol`),
pointed at this working tree:

```sh
make ruby RUBY_REPO=~/Projects/terminalwire/ruby     # corpus + ruby-spec + SimpleCov floor
```

Then this repo's own suite:

```sh
bundle exec rspec        # unit + integration + package smoke tests
```

## Gems (`gem/*`) — publish the OPEN server gems only

The five gems version together off `terminalwire-core`
(`gem/terminalwire-core/lib/terminalwire/version.rb`), but they are **not** licensed
the same, so they do **not** ship the same:

| gem | license (gemspec) | publish? |
|-----|-------------------|----------|
| `terminalwire-core` | `Apache-2.0` (open, shared) | **yes** |
| `terminalwire-server` | `Apache-2.0` (open) | **yes** |
| `terminalwire-rails` | `Apache-2.0` | guarded (raises on build/push) |
| `terminalwire` (metagem, ships `terminalwire-exec`) | `Nonstandard` (proprietary client) | **NO** |
| `terminalwire-client` | `Nonstandard` (proprietary client) | **NO** |

> **Do NOT `rake gem:release`** — it builds + pushes **all five**, which would
> publish the proprietary client gems. That target predates the open-server /
> proprietary-client split.

Publish the two open server gems by hand instead — build, `gem push`, tag **once**
(the per-gem `release` tasks each recreate the shared `v<x>` tag and collide):

```sh
# 1. bump version.rb (drop any .rc; RubyGems `latest` ignores prereleases, so the
#    published "latest" can be BEHIND version.rb — check rubygems, don't trust the file)
# 2. build the two open gems
rake terminalwire_core:build terminalwire_server:build
# 3. auth: no on-disk creds. Mint an API key inline from 1Password (never printed):
KEY=$(curl -s -u "$(op read op://Private/Rubygems/email):$(op read op://Private/Rubygems/password)" \
  -H "OTP: $(op item get Rubygems --otp)" https://rubygems.org/api/v1/api_key.yaml \
  | awk -F': ' '/rubygems_api_key/{print $2}')
# 4. push CORE FIRST (server depends on it), then tag once
GEM_HOST_API_KEY="$KEY" gem push gem/terminalwire-core/pkg/terminalwire-core-<x>.gem
GEM_HOST_API_KEY="$KEY" gem push gem/terminalwire-server/pkg/terminalwire-server-<x>.gem
git tag -a v<x> -m "v<x>" && git push origin v<x>
```

Known gaps (fine, but don't be surprised): the gems set the SPDX `license` field but
**don't bundle the `LICENSE.txt` text** (it's at repo root, not in each gem dir), and
the gem-page READMEs only refresh on the next publish.

## v2 gems (`v2/ruby` + `gem/terminalwire-rails`) — GA at 2.0.0

The v2 `terminalwire` gem (`v2/ruby/lib/terminalwire/v2/version.rb`) and the
`terminalwire-rails` drop-in reached GA at **2.0.0** — the ship-guards and the
`rubygems.invalid` push host are gone, and their push host is `rubygems.org`. Both
version off `Terminalwire::V2::VERSION` and `terminalwire-rails` pins `terminalwire`
to the exact same version, so they release together.

To cut a v2 release:

```sh
# 1. bump v2/ruby/lib/terminalwire/v2/version.rb
# 2. finalize the CHANGELOG heading (date + link ref)
# 3. build + push both, in dependency order (terminalwire first)
cd v2/ruby && gem build terminalwire.gemspec && gem push terminalwire-*.gem
cd ../../gem/terminalwire-rails && gem build terminalwire-rails.gemspec && gem push terminalwire-rails-*.gem
# 4. tag once: git tag v<x> && git push origin v<x>
```

The v1 `terminalwire`/`terminalwire-client` gems in the table above are a **separate,
proprietary line** and are still never published — don't confuse them with the
Apache-2.0 v2 `terminalwire` gem cut here.

> Note: the `build/` Tebako packaging tasks in the root `Rakefile` are v1-only
> (the v1 self-contained binary). v2 distribution is the Go client in
> `terminalwire/cli` — see that repo's `docs/RELEASING.md`. Tebako is not used for v2.
