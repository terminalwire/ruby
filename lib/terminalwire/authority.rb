require "uri"
require "base64"

# Resolves domains into authorities, which are is used for access
# identity control in Terminalwire.
class Terminalwire::Authority
  # Used to seperate path keys in the URL.
  PATH_SEPERATOR = "/".freeze

  # Used to demark a URL string as authorative.
  SCHEME = "terminalwire://".freeze

  def initialize(url:)
    @url = URI(url)
  end

  # Extracted from HTTP. This is so we can
  def domain
    if @url.port == @url.default_port
      @url.host
    else
      "#{url.host}:#{url.port}"
    end
  end

  # Make sure there's always a / at the end of the path.
  def path
    path_keys.join(PATH_SEPERATOR).prepend(PATH_SEPERATOR)
  end

  def to_s
    [SCHEME, domain, path].join
  end

  def key
    Base64.urlsafe_encode64(to_s)
  end

  protected

  def path_keys
    @url.path.scan(/[^\/]+/)
  end
end
