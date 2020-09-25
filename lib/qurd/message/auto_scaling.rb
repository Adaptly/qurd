# rubocop:disable Metrics/LineLength
module Qurd
  class Message
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
    class AutoScaling < ::Qurd::Message

      #
      # @param [Hash] attrs
      # @option attrs [Aws::Credentials] :aws_credentials
      # @option attrs [String] :name
      # @option attrs [String] :queue_url
      # @option attrs [String] :region msg AWS SQS message
      # @option attrs [Struct] :message AWS SQS message
      def initialize(attrs)
        super
        @context = qurd_config.get_context(name: @name,
                                           queue_name: (@queue_url[/[^\/]+$/] rescue nil),
                                           instance_id: instance_id,
                                           message_id: message_id,
                                           action: action)

        qurd_logger.info received: body.Subject, cause: message.Cause, event: message.Event
      end

      # message method will mash keys
      # +StatusCode+, +Service+, +AutoScalingGroupName+, +Description+,
      # +ActivityId+, +Event+, +Details+ +AutoScalingGroupARN+ +Progress+ +Time+
      # +AccountId+ +RequestId+, +StatusMessage+ +EndTime+ +EC2InstanceId+
      # +StartTime+ +Cause+
      # @return [Hashie::Mash]

      # The SQS message's +EC2InstanceId+
      # @return [String]
      def instance_id
        @instance_id ||= message.EC2InstanceId
      end

      # Memozied EC2 instance. Caller must anticipate +nil+ results, as instances
      # may terminate before the message is received.
      # @param [Fixnum] tries The number of times to retry the Aws API
      # @return [Struct|nil]
      def instance(tries = nil)
        return @instance if defined? @instance
        @instance = aws_instance(tries)
      end

      # Memoize the instance's +Name+ tag
      def instance_name
        return @instance_name if defined? @instance_name
        @instance_name = instance.tags.find do |t|
          t.key == 'Name'
        end.value
        qurd_logger.debug("Found instance name '#{@instance_name}'")
        @instance_name
      rescue NoMethodError
        qurd_logger.debug('No instance found')
        @instance_name = nil
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

    end
  end
end
