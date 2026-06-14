require "spec_helper"

# Smoke-test the locally-staged package. `build/` is gitignored and only exists
# after a packaging build, so skip when the artifact is absent (fresh checkout / CI).
# The package now ships only `terminalwire-exec` (the stub reader) — see commit
# b962096 "Build only terminalwire-exec" — so we assert that the packed binary boots
# (its embedded Ruby runs and reports usage) rather than the old `terminalwire` CLI.
RSpec.describe "Local package" do
  let(:bin) { Pathname.new("build/stage/macos/arm64/bin/terminalwire-exec") }

  before { skip "no staged package at #{bin} (run the packaging build first)" unless bin.exist? }

  it "boots terminalwire-exec" do
    # Strip bundler's env (RUBYOPT/GEM_*/BUNDLE_*) so it doesn't leak into the
    # self-contained Tebako binary and break its packed `require`.
    output = Bundler.with_unbundled_env { `#{bin.expand_path} 2>&1` }
    expect(output).to include("Launched with incorrect arguments")
  end
end
