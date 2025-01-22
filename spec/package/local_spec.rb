require "spec_helper"

RSpec.describe "Local package" do
  let(:path) { Pathname.new("build/stage/macos/arm64") }
  before do
    @env = ENV.to_h
    ENV.replace(
      "PATH" => [path.join("bin"), ENV.fetch("PATH")].join(":")
    )
  end
  after do
    ENV.replace @env
  end

  it "runs terminalwire" do
    expect(`terminalwire`).to include <<~TEXT
      Commands:
        terminalwire apps                                   # List apps installed i...
        terminalwire distribution                           # Publish & manage dist...
        terminalwire distribution create NAME               # Distribute app from t...
      TEXT
  end
end
