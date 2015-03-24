# rubocop:disable Metrics/LineLength
module Qurd
  # Convert an SQS auto scaling message to a more usable object
  # @example SQS auto scaling message
  #   {
  #     "Type" : "Notification",
  #     "MessageId" : "e4379a5a-e119-53f7-b6ef-d7dbd32d31fe",
  #     "TopicArn" : "arn:aws:sns:us-east-1:123456890:test-ScalingNotificationsTopic-HPPYDAYSAGAIN",
  #     "Subject" : "Auto Scaling: termination for group \"test2-AutoScalingGroup-1QDX3CNO5SU3D\"",
  #     "Message" : "{\"StatusCode\":\"InProgress\",\"Service\":\"AWS Auto Scaling\",\"AutoScalingGroupName\":\"test2-AutoScalingGroup-1QDX3CNO5SU3D\",\"Description\":\"Terminating EC2 instance: i-08e58cf8\",\"ActivityId\":\"93faaf3a-28cb-4982-a690-0a73c989ab1f\",\"Event\":\"autoscaling:EC2_INSTANCE_TERMINATE\",\"Details\":{\"Availability Zone\":\"us-east-1a\",\"Subnet ID\":\"subnet-3c3e0e14\"},\"AutoScalingGroupARN\":\"arn:aws:autoscaling:us-east-1:123456890:autoScalingGroup:4edb2535-5015-4b81-b668-88ecb0effcb7:autoScalingGroupName/test2-AutoScalingGroup-1QDX3CNO5SU3D\",\"Progress\":50,\"Time\":\"2015-03-16T19:33:08.181Z\",\"AccountId\":\"123456890\",\"RequestId\":\"93faaf3a-28cb-4982-a690-0a73c989ab1f\",\"StatusMessage\":\"\",\"EndTime\":\"2015-03-16T19:33:08.181Z\",\"EC2InstanceId\":\"i-08e58cf8\",\"StartTime\":\"2015-03-16T19:29:14.911Z\",\"Cause\":\"At 2015-03-16T19:29:14Z an instance was taken out of service in response to a ELB system health check failure.\"}",
  #     "Timestamp" : "2015-03-16T19:33:08.242Z",
  #     "SignatureVersion" : "1",
  #     "Signature" : "I+SE8tMiq13/wDTPTJnJvHYi3jSjChhYByJAsnhY0wGa+0lxXc18vPIn9hIT0tYRNWMcR/Xn1AUNsgHrLjzB93xukyKA2CDff08zIuP0l4Xle/FSEJzfkJ0FDqZnzelFuZ2PMtO3lf5UY7CWZg/wKJv6I9CNJF4Ll9YgvC8Moe/31VwJwNy4TRAWdBhDuRXLjbEHoFNGjaGquiduOGySrgRmm74d0P0zWj7IfWbqO6ReNG2ADrqw+Bhn6dAkkeFH+9vJZeKdUCgsXX8XCBHcWX+yAb4WJH90hdosLN12DCdn2AvNgQfoTdpDPkTHC+QcwfRs52d3MD2WLrUfBMBy0A==",
  #     "SigningCertURL" : "https://sns.us-east-1.amazonaws.com/SimpleNotificationService-d6d679a1d18e95c2f9ffcf11f4f9e198.pem",
  #     "UnsubscribeURL" : "https://sns.us-east-1.amazonaws.com/?Action=Unsubscribe&SubscriptionArn=arn:aws:sns:us-east-1:123456890:test-ScalingNotificationsTopic-HPPYDAYSAGAIN:bd850bb2-1a69-4456-a517-c645a26f54b2"
  #   }
  class Message
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
      @context = qurd_config.get_context(name: @name,
                                         queue_name: (@queue_url[/[^\/]+$/] rescue nil),
                                         instance_id: instance_id,
                                         message_id: message_id,
                                         action: action)

      qurd_logger.info "Received #{body.Subject} Cause #{message.Cause} Event #{message.Event}"
    end

    # Convert the SQS message +body+ to a mash, keys include +Type+, +MessageId+,
    # +TopicArn+, +Subject+, +Message+, +Timestamp+, +SignatureVersion+,
    # +Signature+, +SigningCertURL+, +UnsubscribeURL+
    # @return [Hashie::Mash]
    def body
      @body ||= Hashie::Mash.new JSON.load(@sqs_message.body)
    rescue JSON::ParserError
      @body = Hashie::Mash.new {}
    end

    # Convert +body.Message+ to a mash, keys include
    # +StatusCode+, +Service+, +AutoScalingGroupName+, +Description+,
    # +ActivityId+, +Event+, +Details+ +AutoScalingGroupARN+ +Progress+ +Time+
    # +AccountId+ +RequestId+, +StatusMessage+ +EndTime+ +EC2InstanceId+
    # +StartTime+ +Cause+
    # @return [Hashie::Mash]
    def message
      @message ||= Hashie::Mash.new JSON.load(body.Message)
    rescue JSON::ParserError
      @message = Hashie::Mash.new {}
    end

    # The SQS message's +EC2InstanceId+
    # @return [String]
    def instance_id
      @instance_id ||= message.EC2InstanceId
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

    # Memozied EC2 instance. Caller must anticipate +nil+ results, as instances
    # may terminate before the message is received.
    # @param [Fixnum] tries The number of times to retry the Aws API
    # @return [Struct|nil]
    def instance(tries = nil)
      return @instance if @instance
      @instance = aws_instance(tries)
    end

    # Memoize the instance's +Name+ tag
    def instance_name
      return @instance_name if @instance_name
      @instance_name = instance.tags.find do |t|
        t.key == 'Name'
      end.value
      qurd_logger.debug("Found instance name '#{@instance_name}'")
      @instance_name
    rescue NoMethodError
      qurd_logger.debug('No instance found')
      @instance_name = nil
    end

    # Convert the +message.Event+ to an action
    # @return [String] +launch+, +launch_error+, +terminate+, +terminate_error+,
    #   or +test+
    def action
      case message.Event
      when 'autoscaling:EC2_INSTANCE_LAUNCH' then 'launch'
      when 'autoscaling:EC2_INSTANCE_LAUNCH_ERROR' then 'launch_error'
      when 'autoscaling:EC2_INSTANCE_TERMINATE' then 'terminate'
      when 'autoscaling:EC2_INSTANCE_TERMINATE_ERROR' then 'terminate_error'
      when 'autoscaling:TEST_NOTIFICATION' then 'test'
      else
        qurd_logger.info "Ignoring #{message.Event}"
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
      context.clear
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

    # Get the Aws EC2 instance, using +instance_id+
    # @param [Fixnum] tries the number of retries
    # @return [Struct|nil]
    # @see instance_id
    # @see instance
    def aws_instance(tries = nil)
      return unless instance_id
      aws_retryable(tries) do
        aws_client(:EC2).describe_instances(
          instance_ids: [instance_id]
        ).reservations.first.instances.first
      end
    rescue NoMethodError
      nil
    end

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
