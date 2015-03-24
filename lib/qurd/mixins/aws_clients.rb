module Qurd
  module Mixins
    # Generic method for instantiating Aws clients
    module AwsClients
      # Memoize Aws clients, the caller must respond to +region+ and
      # +aws_credentials+
      # @param [String|Symbol] client the name of the client to instantiate
      # @return [Object] an Aws client
      # @example SQS
      #   executor.aws_client(:SQS).list_queues
      # @example EC2
      #   executor.aws_client("EC2").describe_instances
      # @raise [NameError] if the +client+ is not a valid Aws client class
      def aws_client(client)
        @qurd_aws_clients ||= {}
        klass = Object.const_get("Aws::#{client}::Client")
        @qurd_aws_clients[client.to_sym] ||= klass.new(
          region: region,
          credentials: aws_credentials)
      end

      # Wrap a block in a +begin+ +rescue+, which retries, if
      # +Aws::Errors::ServiceError+ is raised. The method will retry the block
      # immediately, up to n +tries+.
      # @param [Fixnum] tries
      # @raise [Aws::Errors::ServiceError] Any number of Aws error classes
      def aws_retryable(tries = 2)
        tries = [1, tries.to_i].max
        begin
          yield
        rescue Aws::Errors::ServiceError => e
          (tries -= 1).zero? ? raise(e) : retry
        end
      end
    end
  end
end
