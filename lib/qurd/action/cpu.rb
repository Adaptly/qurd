require 'qurd/action'
module Qurd
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
  class Action
    # Terminate EC2 instances, based on CPU alerts
    # @example Cpu configuration
    #   cpu_queues:
    #     staging:
    #       region: us-east-1
    #       queues:
    #         - "/QueueName/i"
    class Cpu < Action
      # Parent class for errors
      class Errors < StandardError
        # too many ec2 instances associated with the auto scaling group
        class TooManyInstances; end
      end

      @configure_done = false
      # Verify each +cpu_queue+ is correct
      # @param [String] _action the action being configured
      # @raise [RuntimeError] if any +cpu_queues+ aren't configured
      def self.configure(_action)
        return if @configure_done
        check_configuration
        @configure_done = true
      end

      # Delete the record, if the message did not fail other processing steps and
      # dry_run is not true
      # @see {#Qurd::Message}
      def terminate
        if failed?
          qurd_logger.warn('Not deleting, message failed to process')
        elsif qurd_configuration.dry_run
          if !auto_scaling_group
            qurd_logger.debug('Dry run; missing auto scaling group')
          elsif !auto_scaling_group_instance_id
            qurd_logger.debug('Dry run; missing auto scaling group instance id')
          else
            qurd_logger.debug('Dry run; would delete')
          end
        else
          terminate_instance
        end
      end

      # Respond to test actions
      def test
        qurd_logger.info('Test')
      end

      # Terminate the EC2 instance associated with the auto scaling group
      def terminate_instance
        ec2.terminate_instance instance_id: auto_scaling_group_instance_id
      end

      def auto_scaling_group_instance_id
        raise Errors::TooManyInstances if auto_scaling_group.instances.count > 1
        @auto_scaling_group_instance_id ||= auto_scaling_group.instances[0].instance_id
      end

      def auto_scaling_group
        return @auto_scaling_group if @auto_scaling_group
        g = asg.describe_auto_scaling_groups auto_scaling_group_names: [message.AutoScalingGroupName]
        @auto_scaling_group = g.auto_scaling_groups.first
      end

      private

      def ec2
        @ec2 ||= aws_client(:Ec2)
      end

      def asg
        @asg ||= aws_client(:AutoScaling)
      end

      def qurd_ec2
        @config ||= qurd_configuration.cpu_queues[name]
      end

      def self.config_valid?(name)
        if qurd_configuration.cpu_queues.nil? || \
           qurd_configuration.cpu_queues[name].nil? || \
           qurd_configuration.cpu_queues[name].queues.nil? || \
           qurd_configuration.cpu_queues[name].queues.empty?
          false
        else
          true
        end
      end

      def self.check_configuration
        missing = []
        qurd_configuration.cpu_queues.each do |name, _monitor|
          missing << name unless config_valid?(name)
        end
        m = missing.join(', ')
        qurd_logger! "Missing configuration for ec2: #{m}" unless m.empty?
      end
    end
  end
end
