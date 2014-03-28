# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)

require 'leaderboard/version'

Gem::Specification.new do |s|
  s.name        = "leaderboard"
  s.version     = Leaderboard::VERSION.dup
  s.authors     = ["David Czarnecki"]
  s.email       = ["dczarnecki@agoragames.com"]
  s.homepage    = "https://github.com/agoragames/leaderboard"
  s.summary     = %q{Leaderboards backed by Redis in Ruby}
  s.description = %q{Leaderboards backed by Redis in Ruby}
  s.license = 'MIT'

  s.rubyforge_project = "leaderboard"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency('redis')
  s.add_development_dependency('rake')
  s.add_development_dependency('rspec')
end
