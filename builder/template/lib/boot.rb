# Resolve the package root directory (two levels up from this file)
vendor_path = File.expand_path("../../vendor", __FILE__)

# Add the Ruby standard library path
stdlib_path = File.join(vendor_path, "lib/ruby", RUBY_VERSION)
$LOAD_PATH.unshift(stdlib_path) unless $LOAD_PATH.include?(stdlib_path)

# Add all gem paths under gems to the load path
Dir.glob(File.join(vendor_path, "gems/gems/*/lib")).each do |gem_path|
  $LOAD_PATH.unshift(gem_path)
end

# Set GEM environment variables for runtime
ENV["GEM_HOME"] = File.join(vendor_path, "gems")
ENV["GEM_PATH"] = ENV["GEM_HOME"]
ENV["PATH"] = [
  File.join(vendor_path, "bin"),
  ENV["PATH"]
].join(":")
