# -*- encoding: utf-8 -*-
require File.expand_path('../lib/red_trend/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Brendon Murphy"]
  gem.email         = ["xternal1+github@gmail.com"]
  gem.description   = %q{Store your trend data in redis}
  gem.summary       = gem.description
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "red_trend"
  gem.require_paths = ["lib"]
  gem.version       = RedTrend::VERSION

  gem.add_dependency "redis"

  gem.add_development_dependency "rake"
  gem.add_development_dependency "rspec"
  gem.add_development_dependency "integration_test_redis"
  gem.add_development_dependency "timecop"
  gem.add_development_dependency "tzinfo"
end
