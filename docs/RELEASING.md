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

## v1 gems (`gem/*`) — published

The v1 line is five gems versioned together off `terminalwire-core`
(`gem/terminalwire-core/lib/terminalwire/version.rb`): `terminalwire-core`,
`-client`, `-server`, `-rails`, and the `terminalwire` metagem. They release in
dependency order via the root `Rakefile`:

```sh
rake gem:releasable      # guard: fails unless git is clean AND synced with origin
rake gem:build           # build all five
rake gem:release         # build + push all five to RubyGems (tags + pushes)
```

Per-gem tasks exist too (e.g. `rake terminalwire_core:release`). Bump the version
in `version.rb`, update `CHANGELOG.md`, then `rake gem:release`.

## v2 gem (`v2/ruby`) — guarded until GA

The v2 `terminalwire` gem (`v2/ruby/lib/terminalwire/v2/version.rb`, currently
`2.0.0.alpha1`) is **intentionally unpublishable**: its gemspec raises on
`gem build|push|release` and its push host is `rubygems.invalid`, so it can't be
shipped by accident while v2 is in alpha. It's distributed today only by Git ref /
path while it stabilizes.

To publish at GA: remove the guard + invalid host in `v2/ruby/terminalwire.gemspec`,
set the release version, then `cd v2/ruby && gem build && gem push`.

> Note: the `build/` Tebako packaging tasks in the root `Rakefile` are v1-only
> (the v1 self-contained binary). v2 distribution is the Go client in
> `terminalwire/cli` — see that repo's `docs/RELEASING.md`. Tebako is not used for v2.
