# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'uvi/version'

Gem::Specification.new do |spec|
  spec.name          = "uvi"
  spec.version       = Uvi::VERSION
  spec.authors       = ["Sava Chankov", "Denitsa Belogusheva"]
  spec.email         = ["sava@tutuf.com", "deni@tutuf.com"]
  spec.homepage      = "http://github.com/tutuf/uvi"
  spec.summary       = %q{Class table inheritance for ActiveRecord}
  spec.description   = %q{Uvi relies on updatable views in the database that join parent and children tables}
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  s.add_dependency "activerecord", "~>3.2.12"
  s.add_dependency "pg"
  
  spec.add_development_dependency "rake"
end
