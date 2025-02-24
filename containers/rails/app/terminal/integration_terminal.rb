class IntegrationTerminal < ApplicationTerminal
  desc "exception", "Raise an exception"
  def exception
    raise "An exception occurred"
  end
end
