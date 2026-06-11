# frozen_string_literal: true

# The Rack adapter captures the incoming connection profile (host/ip/user_agent/
# headers) and the Context surfaces it — so server code (and `terminalwire about`)
# can see who connected. The client identifies itself in HEADERS (a real
# User-Agent), never in the URL; client_version is parsed from that UA.
require "terminalwire/v2"

RSpec.describe "v2 context connection profile" do
  def ctx(request)
    c = Terminalwire::V2::Server::Context.allocate
    c.instance_variable_set(:@request, request)
    c
  end

  it "exposes ip, user_agent, and headers from the request" do
    c = ctx(ip: "1.2.3.4",
            user_agent: "terminalwire-exec/2.0.1 (macos-arm64; channel alpha; protocol 2)",
            headers: { "Host" => "terminalwire.com", "User-Agent" => "x" })
    expect(c.remote_ip).to eq "1.2.3.4"
    expect(c.user_agent).to include "terminalwire-exec/2.0.1"
    expect(c.http_headers.keys).to contain_exactly("Host", "User-Agent")
  end

  it "parses client_version from the User-Agent (a header, not the URL)" do
    expect(ctx(user_agent: "terminalwire-exec/2.0.1 (macos-arm64; channel alpha)").client_version).to eq "2.0.1"
  end

  it "degrades cleanly when the client sent no User-Agent" do
    c = ctx({})
    expect(c.client_version).to be_nil
    expect(c.user_agent).to be_nil
    expect(c.http_headers).to eq({})
  end

  describe "header allowlist (sane client headers, no infra chrome)" do
    subject(:rack) { Terminalwire::V2::Server::Rack.new(Class.new) }

    it "keeps standard client headers, drops Fly/proxy/handshake noise" do
      headers = rack.send(:http_headers, {
        "HTTP_USER_AGENT"             => "terminalwire-exec/2.0.1",
        "HTTP_HOST"                   => "terminalwire.com",
        "HTTP_SEC_WEBSOCKET_PROTOCOL" => "terminalwire.v2",
        "HTTP_FLY_CLIENT_IP"          => "1.2.3.4",
        "HTTP_X_FORWARDED_FOR"        => "1.2.3.4, 5.6.7.8",
        "HTTP_VIA"                    => "1.1 fly.io",
        "HTTP_X_REQUEST_START"        => "t=123",
        "HTTP_SEC_WEBSOCKET_KEY"      => "nonce==",
      })
      expect(headers.keys).to contain_exactly("User-Agent", "Host", "Sec-Websocket-Protocol")
    end
  end
end
