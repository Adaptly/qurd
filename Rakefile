require "bundler/gem_tasks"
require "rake/testtask"
require 'ci/reporter/rake/minitest'
task :minitest => ['ci:setup:minitest', 'test']

Rake::TestTask.new do |t|
  t.pattern = "test/*_test.rb"
  t.libs << "test"
end

task default: [:test]
