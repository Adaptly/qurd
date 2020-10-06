# rubocop:disable Metrics/LineLength
module Qurd
  class Message
    # @example SQS alarm message
    # {
    #   "Type": "Notification",
    #   "MessageId": "15bcca60-a8f9-536a-871c-9d85c15f6490",
    #   "TopicArn": "arn:aws:sns:us-west-2:105191381127:staging-notifications-19NH4PMMXT1V2-AlarmTopic-245OJ740R13I",
    #   "Subject": "ALARM: \"test-etcd0\" in US West (Oregon)",
    #   "Message": "{\"AlarmName\":\"test-etcd0\",\"AlarmDescription\":null,\"AWSAccountId\":\"105191381127\",\"NewStateValue\":\"ALARM\",\"NewStateReason\":\"Threshold Crossed: 2 out of the last 2 datapoints [0.6832886416666666 (23/09/20 14:19:00), 0.0 (23/09/20 13:19:00)] were less than or equal to the threshold (10.0) (minimum 2 datapoints for OK -> ALARM transition).\",\"StateChangeTime\":\"2020-09-23T15:19:02.839+0000\",\"Region\":\"US West (Oregon)\",\"AlarmArn\":\"arn:aws:cloudwatch:us-west-2:105191381127:alarm:test-etcd0\",\"OldStateValue\":\"INSUFFICIENT_DATA\",\"Trigger\":{\"MetricName\":\"CPUCreditBalance\",\"Namespace\":\"AWS/EC2\",\"StatisticType\":\"Statistic\",\"Statistic\":\"AVERAGE\",\"Unit\":null,\"Dimensions\":[{\"value\":\"k9s-staging-Etcd-1KZET9BPNMF7R-Etcdv3dot3i1-V19PYAB8JU2N\",\"name\":\"AutoScalingGroupName\"}],\"Period\":3600,\"EvaluationPeriods\":2,\"ComparisonOperator\":\"LessThanOrEqualToThreshold\",\"Threshold\":10.0,\"TreatMissingData\":\"- TreatMissingData:                    missing\",\"EvaluateLowSampleCountPercentile\":\"\"}}",
    #   "Timestamp": "2020-09-23T15:19:02.893Z",
    #   "SignatureVersion": "1",
    #   "Signature": "gRubQFrCgiJ12RJHEYSqEk9dI8/QbustBbQkKfrvytieS+aM1t45jWql5wbjRI/YgppLK2btBZfGH69H2hTHO0kmIflvZfOV3IgOMB+L9AacZgrqRdHPmaj0vF7tJkhk++DOYGQjkpa+4G2/pUyyx9qeVwMqlV7x2RI4un8zf+4G0xUQvHboEB7cvBZ+WWGTsXY974NwiwigY8739SWloIeZ4fj5o2Bu92WRTdEnGSbz7BVPsvA++j5p/CHerzJrgFM7gRBPWipGJ8oEuUSqoESNToDywHwAR0pjmfANVE/5/GcfeLWVrxodbXgP9CqaXk/nl3p8HROT4Dqe+XDknA==",
    #   "SigningCertURL": "https://sns.us-west-2.amazonaws.com/SimpleNotificationService-a86cb10b4e1f29c941702d737128f7b6.pem",
    #   "UnsubscribeURL": "https://sns.us-west-2.amazonaws.com/?Action=Unsubscribe&SubscriptionArn=arn:aws:sns:us-west-2:105191381127:staging-notifications-19NH4PMMXT1V2-AlarmTopic-245OJ740R13I:8486ec0e-9928-426c-9cf6-e49f94424048"
    # }
    class Alarm < ::Qurd::Message
      class Errors
        # too many ec2 instances associated with the auto scaling group
        class TooManyInstances < StandardError; end
        # The ASG was not found in the SQS message
        class AutoScalingGroupNameNotFound < StandardError; end
      end

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

        qurd_logger.info received: body.Subject, dimensions: message.Trigger.Dimensions
      end

      # message method
      # Convert +body.Message+ to a mash, keys include
      # +AlarmName+, +AlarmDescription+, +AWSAccountId+, +NewStateValue+,
      # +NewStateReason+, +Region+, +AlarmArn+, +OldStateValue+, +Trigger+,
      # +Trigger.MetricName+, +Trigger.Namespace+, +Trigger.StatisticType+, 
      # +Trigger.Statistic+, +Trigger.Unit+, +Trigger.Dimensions+, 
      # +Trigger.Dimensions[0]+, +Trigger.Period+, +Trigger.EvaluationPeriods+,
      # +Trigger.ComparisonOperator+, +Trigger.Threshold+,
      # +Trigger.TreatMissingData+, +Trigger.EvaluateLowSampleCountPercentile+
      # @return [Hashie::Mash]

      # The EC2 instance id associated with the auto scaling group
      # @return [String]
      def instance_id
        raise Errors::TooManyInstances if auto_scaling_group.instances.count > 1
        @instance_id ||= auto_scaling_group.instances.first.instance_id
      end

      private

      def auto_scaling_group_name
        g = message.Trigger.Dimensions.find{|d| d["name"] == "AutoScalingGroupName"}["value"]
        raise Errors::AutoScalingGroupNameNotFound if g.nil?
        @auto_scaling_group_name = g
      rescue NoMethodError => e
        raise Errors::AutoScalingGroupNameNotFound
      end

      def auto_scaling_group
        return @auto_scaling_group if defined? @auto_scaling_group
        g = aws_client(:AutoScaling).describe_auto_scaling_groups auto_scaling_group_names: [auto_scaling_group_name]
        @auto_scaling_group = g.auto_scaling_groups.first
      end

    end
  end
end
