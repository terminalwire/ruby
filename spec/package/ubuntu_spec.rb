require "spec_helper"

# Smoke-test the staged Ubuntu package inside its container. Skips when the staged
# artifact is absent (build/ is gitignored) or Docker isn't available. The package
# ships only `terminalwire-exec` now (commit b962096 "Build only terminalwire-exec"),
# so we assert the packed binary boots inside the container rather than the old CLI.
RSpec.describe "Ubuntu package" do
  let(:path) { Pathname.new("build/stage/ubuntu/arm64") }
  let(:container_name) { "terminalwire_ubuntu_specs" }

  before do
    skip "no staged package at #{path} (run the packaging build first)" unless path.join("bin/terminalwire-exec").exist?
    skip "docker not available" unless system("docker info >/dev/null 2>&1")
    `docker build -t #{container_name} containers/ubuntu`
  end

  it "boots terminalwire-exec" do
    output = `docker run -v #{path.expand_path}:/opt/terminalwire #{container_name} terminalwire-exec 2>&1`
    expect(output).to include("Launched with incorrect arguments")
  end
end
