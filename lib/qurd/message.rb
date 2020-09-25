# rubocop:disable Metrics/LineLength
module Qurd
  # Convert an SQS auto scaling message to a more usable object
  class Message
    autoload :Alarm, 'qurd/message/alarm'
    autoload :AutoScaling, 'qurd/message/auto_scaling'
    extend Qurd::Mixins::Configuration

    # Add setter and getter instances methods. If the get or set method is
    # already defined, an exception will be raised.
    # @param [Symbol] name the name of the method to add
    def self.add_accessor(name)
      if instance_methods.include?(name) ||
         instance_methods.include?("#{name}=")
        qurd_logger.warn "Can not replace a method! (#{name})"
      end
      attr_accessor name
    end

    include Qurd::Mixins::Configuration
    include Qurd::Mixins::AwsClients
    # @!attribute aws_credentials [r]
    #   @return [Aws::Credentials]
    # @!attribute context [r]
    #   Cabin::Channel logs messages as well as context. Context is retained
    #   until it is cleared.
    #   @return [Cabin::Context] Context data
    # @!attribute exceptions [r]
    #   Action exceptions
    #   @return [Array<Exception>]
    # @!attribute name [r]
    #   The Listener name
    #   @return [String]
    # @!attribute queue_url [r]
    #   The SQS url the message came from
    #   @return [String]
    # @!attribute region [r]
    #   AWS region
    #   @return [String]
    attr_reader :aws_credentials,
                :context,
                :exceptions,
                :name,
                :queue_url,
                :region

    #
    # @param [Hash] attrs
    # @option attrs [Aws::Credentials] :aws_credentials
    # @option attrs [String] :name
    # @option attrs [String] :queue_url
    # @option attrs [String] :region msg AWS SQS message
    # @option attrs [Struct] :message AWS SQS message
    def initialize(attrs)
      @aws_credentials = attrs[:aws_credentials]
      @name = attrs[:name]
      @queue_url = attrs[:queue_url]
      @region = attrs[:region]
      @sqs_message = attrs[:message]

      @exceptions = []
      @failed = false
    end

    # Convert the SQS message +body+ to a mash, keys include +Type+, +MessageId+,
    # +TopicArn+, +Subject+, +Message+, +Timestamp+, +SignatureVersion+,
    # +Signature+, +SigningCertURL+, +UnsubscribeURL+
    # @return [Hashie::Mash]
    def body
      @body ||= Hashie::Mash.new JSON.load(@sqs_message.body)
    rescue JSON::ParserError => e
      qurd_logger.error "Failed to parse body: #{e}"
      @body = Hashie::Mash.new {}
    end

    # Convert +body.Message+ to a mash
    # @return [Hashie::Mash]
    def message
      @message ||= Hashie::Mash.new JSON.load(body.Message)
    rescue JSON::ParserError => e
      qurd_logger.error "Failed to parse message: #{e}"
      @message = Hashie::Mash.new {}
    end

    # The +body.MessageId+
    # @return [String]
    def message_id
      @message_id ||= body.MessageId
    end

    # The SQS +receipt_handle+, used to delete a message
    # @return [String]
    def receipt_handle
      @sqs_message.receipt_handle
    end

    # Record an action failure
    # @param [Exception] e The exception
    def failed!(e = nil)
      qurd_logger.debug 'Failed'
      @exceptions << e if e
      @failed = true
      nil
    end

    # Has processing the message failed
    # @return [Boolean]
    def failed?
      @failed == true
    end

    # Convert the +message.Event+ to an action
    # @return [String] +launch+, +launch_error+, +terminate+, +terminate_error+,
    #   or +test+
    def action
      if body.Subject =~ /^Auto Scaling: /
        case message.Event
        when 'autoscaling:EC2_INSTANCE_LAUNCH' then 'launch'
        when 'autoscaling:EC2_INSTANCE_LAUNCH_ERROR' then 'launch_error'
        when 'autoscaling:EC2_INSTANCE_TERMINATE' then 'terminate'
        when 'autoscaling:EC2_INSTANCE_TERMINATE_ERROR' then 'terminate_error'
        when 'autoscaling:TEST_NOTIFICATION' then 'test'
        else
          qurd_logger.warn "Ignoring ASG #{message.Event}"
          failed!
        end
      elsif body.Subject =~ /^ALARM: /
        if message.NewStateValue == 'ALARM'
          'terminate'
        else
          qurd_logger.warn "Ignoring Alarm #{message.NewStateValue}"
          failed!
        end
      else
        qurd_logger.error "Ignoring unknown subject #{body.Subject}"
        failed!
      end
    end

    # Delete an AWS SQS message
    def delete
      qurd_logger.debug('Preparing to delete message')
      if failed? && qurd_configuration.save_failures
        qurd_logger.error 'Message failed processing, not deleting'
      elsif qurd_configuration.dry_run
        qurd_logger.info 'Dry run'
      else
        delete_message
      end
      context.clear if context
    end

    def instance_id
      raise "Must be overridden"
    end

    # @private
    def inspect
      format('#<Qurd::Message message_id:%s subject:%s cause:%s ' \
             'instance_id:%s instance:%s>',
             message_id,
             body.Subject,
             message.Cause,
             instance_id,
             instance)
    end

    private

    def delete_message
      qurd_logger.info 'Deleting'
      begin
        aws_client(:SQS).delete_message(queue_url: queue_url,
                                        receipt_handle: receipt_handle)
      rescue Aws::SQS::Errors::ReceiptHandleIsInvalid
        qurd_logger.info('SQS message deleted already or timed out')
      rescue Aws::SQS::Errors::ServiceError => e
        qurd_logger.error("SQS raised #{e}")
        raise e
      end
    end

  end
end
