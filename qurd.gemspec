# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'qurd/version'

Gem::Specification.new do |spec|
  spec.name          = "qurd"
  spec.version       = Qurd::VERSION
  spec.authors       = ["Philip Champon"]
  spec.email         = ["philip@adaptly.com"]
  spec.summary       = %q{QUeue Resource Daemon: reaping and sowing your auto-scaled resources}
  spec.description   = %q{Configure resources, based on auto scaling events, published to SQS. Qurd is extensible, simply create a plugin and let it rip.}
  spec.homepage      = "https://github.com/Adaptly/qurd"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.8"
  spec.add_development_dependency "rake", ">= 12.3.3"
  spec.add_development_dependency "minitest"
  spec.add_development_dependency "ci_reporter_minitest"
  spec.add_development_dependency "pry-nav"
  spec.add_development_dependency "webmock"
  spec.add_development_dependency "minitest-matchers_vaccine"

  spec.add_runtime_dependency "cabin", "~> 0.7.0"
  spec.add_runtime_dependency "hashie"
  spec.add_runtime_dependency "aws-sdk-autoscaling", "~> 1"
  spec.add_runtime_dependency "aws-sdk-ec2", "~> 1"
  spec.add_runtime_dependency "aws-sdk-sqs", "~> 1"
  spec.add_runtime_dependency "aws-sdk-route53", "~> 1"
  spec.add_runtime_dependency "chef", "= 15.4.45"
  spec.add_runtime_dependency "chef-zero", "= 14.0.17"
end
