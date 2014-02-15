require 'bundler/gem_tasks'
require 'rake'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.pattern = 'spec/**/*_spec.rb'
  spec.rspec_opts = ['--backtrace']
  # spec.ruby_opts = ['-w']
end

task :default => :spec

desc "Run the specs against Ruby 1.8.7, 1.9.3, 2.0.0"
task :test_rubies do
  system "rvm 1.8.7@leaderboard_gem,1.9.3@leaderboard_gem,2.0.0@leaderboard_gem do rake spec"
end
