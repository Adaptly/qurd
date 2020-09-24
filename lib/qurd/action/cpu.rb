require 'qurd/action'
module Qurd
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
          if !instance_id
            qurd_logger.debug('Dry run; missing instance id')
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
        ec2.terminate_instances instance_ids: [instance_id]
      end

      private

      def ec2
        @ec2 ||= aws_client(:EC2)
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
        qurd_logger! "Missing configuration for cpu_queues: #{m}" unless m.empty?
      end
    end
  end
end
