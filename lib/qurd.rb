require 'rubygems'
require 'bundler/setup'
# monkey patch inspect
require 'hash'
# add method underscore
require 'string'
require 'fileutils'
require 'singleton'
require 'json'
require 'yaml'
require 'hashie'
require 'cabin'
require 'aws-sdk-autoscaling'
require 'aws-sdk-ec2'
require 'aws-sdk-route53'
require 'aws-sdk-sqs'
require 'qurd/version'

# Ain't that some bullshit
module Qurd
  autoload :Action, 'qurd/action'
  autoload :Configuration, 'qurd/configuration'
  autoload :Listener, 'qurd/listener'
  autoload :Message, 'qurd/message'
  autoload :Mixins, 'qurd/mixins'
  autoload :Processor, 'qurd/processor'

  extend Mixins::Configuration

  class << self
    def start(config = nil)
      qurd_config.configure(config)
      daemonize
      listen_to_queues
    end

    private

    def daemonize
      IO.write(qurd_configuration.pid_file, $$)
    end

    # Iterate over listeners and their queues, listen for messages, and
    # processing them
    def listen_to_queues
      threads = qurd_configuration.listeners.map(&:listen).flatten
      $0 = "qurd [#{threads.count} threads]"
      qurd_logger.debug("Threads #{threads}")
      threads.each(&:join)
    end
  end
end
