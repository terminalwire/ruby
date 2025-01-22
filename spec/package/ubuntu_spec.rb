require "spec_helper"

RSpec.describe "Ubuntu package" do
  let(:path) { Pathname.new("build/stage/ubuntu/arm64") }
  let(:container_name) { "terminalwire_ubuntu_specs" }
  before do
    `docker build -t #{container_name} containers/ubuntu`
  end
  it "runs terminalwire" do
    expect(`docker run -v #{path.expand_path}:/opt/terminalwire #{container_name} terminalwire`).to include <<~TEXT
      Commands:
        terminalwire apps                                   # List apps installed i...
        terminalwire distribution                           # Publish & manage dist...
        terminalwire distribution create NAME               # Distribute app from t...
      TEXT
  end
end
