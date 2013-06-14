# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'updateable_views_inheritance/version'

Gem::Specification.new do |s|
  s.name          = "updateable_views_inheritance"
  s.version       = Uvi::VERSION
  s.authors       = ["Sava Chankov", "Denitsa Belogusheva"]
  s.email         = ["sava@tutuf.com", "deni@tutuf.com"]
  s.homepage      = "http://github.com/tutuf/updateable_views_inheritance"
  s.summary       = %q{Class table inheritance for ActiveRecord}
  s.description   = %q{Class table inheritance for ActiveRecord based on updatable views in the database that join parent and children tables}
  s.license       = "MIT"

  s.files         = `git ls-files`.split($/)
  s.executables   = s.files.grep(%r{^bin/}) { |f| File.basename(f) }
  s.test_files    = s.files.grep(%r{^(test|spec|features)/})
  s.require_paths = ["lib"]

  s.add_dependency "activerecord", "~>3.2.12"
  s.add_dependency "pg"
  
  s.add_development_dependency "bundler", "~>1.3"
  s.add_development_dependency "rake"
end
