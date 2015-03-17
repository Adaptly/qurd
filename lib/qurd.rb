require "rubygems"
require "bundler/setup"
require "singleton"
require "json"
require "hash"
require "yaml"
require "hashie"
require "cabin"
require "aws-sdk"
require "qurd/version"

module Qurd
  autoload :Configuration, "qurd/configuration"
  autoload :Message, "qurd/message"
  autoload :Mixins, "qurd/mixins"
  autoload :Actions, "qurd/actions"
  extend Mixins::Configuration
  class << self
    def start
      qurd_config.configure(ARGV[0])
      daemonize
      listen_to_queues
    end

    private

    def daemonize
      IO.write(qurd_configuration.pid_file, $$)
    end

    def listen_to_queues
      loop do
        qurd_accounts.each do |acct|
          acct.queues.each do |q|
            msgs = acct.sqs.receive_message(
              queue_url: q,
              wait_time_seconds: acct.wait_time
            )
            msgs.messages.each do |msg|
              Message.new(queue: q, config: acct, message: msg).process
            end
          end
        end
      end
    end

  end
end
