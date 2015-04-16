require 'forwardable'
module Qurd
  # Subclass and override {#launch}, {#launch_error}, {#terminate},
  # {#terminate_error}, and {#test}, optionally override class method
  # {#Qurd::Action.configure} and instance methods {#run_before} and
  # {#run_after}
  # @abstract
  class Action
    # Raised if the +message+ is invalid
    class InvalidMessage < StandardError; end

    autoload :Dummy, 'qurd/action/dummy'
    autoload :Chef, 'qurd/action/chef'
    autoload :Route53, 'qurd/action/route53'

    extend Forwardable

    extend Qurd::Mixins::Configuration
    include Qurd::Mixins::Configuration

    extend Qurd::Mixins::AwsClients
    include Qurd::Mixins::AwsClients

    # @!attribute aws_credentials [r]
    #   @return [Aws::Credentials]
    def_delegator :@message, :aws_credentials, :aws_credentials
    # @!attribute chef_client
    #   @return [Chef::ApiClient]
    def_delegator :@message, :chef_client, :chef_client
    def_delegator :@message, :chef_client=, :chef_client=
    # @!attribute chef_node
    #   @return [Chef::Node]
    def_delegator :@message, :chef_node, :chef_node
    def_delegator :@message, :chef_node=, :chef_node=
    # @!method failed!(e) [r]
    #   Log an action failure, setting the Qurd::Message
    #   @return [Aws::Credentials]
    #   @see Qurd::Message.failed!
    def_delegator :@message, :failed!, :failed!
    # @!attribute failed? [r]
    #   @return [Boolean]
    def_delegator :@message, :failed?, :failed?
    # @!attribute instance_id [r]
    #   @return [String]
    def_delegator :@message, :instance_id, :instance_id
    # @!attribute instance_name [r]
    #   @return [String]
    def_delegator :@message, :instance_name, :instance_name
    # @!attribute instance [r]
    #   @return [Struct]
    def_delegator :@message, :instance, :instance
    # @!attribute name [r]
    #   @return [String]
    def_delegator :@message, :name, :name
    # @!attribute region [r]
    #   @return [String]
    def_delegator :@message, :region, :region

    # @!attribute context [r]
    #   The logging context
    #   @return [Cabin::Context]
    # @!attribute message [r]
    #   @return [Qurd::Message]
    attr_reader :context, :message

    # Optionally configure the plugin
    # @param [String] _action optionally configure, based on the actions
    # +launch+, +launch_error+, +terminate+, +terminate_error+, or +test+
    def self.configure(_action)
      qurd_logger.debug('Nothing to do')
    end

    # Run the plugin for a given {#Qurd::Message}
    # @param [Qurd::Message] message message The message
    # @raise [Qurd::Action::InvalidMessage] If the +message+ is not a
    #   {#Qurd::Message}
    # @see Qurd::Message
    def initialize(message)
      unless message.is_a?(Qurd::Message)
        qurd_logger!("Message is not a Qurd::Message (#{message.class})",
                     Qurd::Action::InvalidMessage)
      end
      @message = message
      @context = message.context
    end

    # Executed before the processor runs the plugins for an action
    # @see Qurd::Processor
    def run_before
      qurd_logger.debug('Nothing to do')
    end

    # Run the plugin
    def launch
      qurd_logger!("Override the abstract method #{__method__}")
    end
    alias_method :launch_error, :launch
    alias_method :terminate, :launch
    alias_method :terminate_error, :launch
    alias_method :test, :launch

    # Executed after the processor runs the plugins for an action
    # @see Qurd::Processor
    def run_after
      qurd_logger.debug('Nothing to do')
    end

    def inspect
      format('<%s:%x instance_id:%s message_id:%s context:%s>',
             self.class,
             object_id,
             message.instance_id,
             message.message_id,
             context.inspect
      )
    end
  end
end
