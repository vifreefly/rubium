
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "rubium/version"

Gem::Specification.new do |spec|
  spec.name          = "rubium"
  spec.version       = Rubium::VERSION
  spec.authors       = ["Victor Afanasev"]
  spec.email         = ["vicfreefly@gmail.com"]

  spec.summary       = "Headless Chromium Ruby API based on ChromeRemote gem"
  spec.description   = spec.summary
  spec.homepage      = "https://github.com/vifreefly/rubium"
  spec.license       = "MIT"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.require_paths = ["lib"]

  spec.add_dependency "chrome_remote", "~> 0.2"
  spec.add_dependency "cliver", "~> 0.3"
  spec.add_dependency "random-port"
  spec.add_dependency "nokogiri"

  spec.add_development_dependency "bundler", "~> 1.16"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "minitest", "~> 5.0"
end
