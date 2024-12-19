# Resolve the base directory
base_dir = File.expand_path("..", __FILE__)

# Add all gem paths under lib/vendor to the load path
Dir.glob(File.join(base_dir, "vendor/gems/gems/*/lib")).each do |gem_path|
  $LOAD_PATH.unshift gem_path
end
