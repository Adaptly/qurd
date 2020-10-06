#  Gem module
module Qurd
  # Use a {#Qurd::Listener} to act on an AWS SQS message
  class Processor
    class Errors
      # unable to determine message type
      class UnknownSubject < StandardError; end
    end
    include Qurd::Mixins::Configuration
    include Qurd::Mixins::AwsClients

    # @!attribute listener [r]
    #   @return [Qurd::Listener]
    # @!attribute message [r]
    #   @return [Qurd::Message]
    attr_reader :listener, :message

    # @param [Qurd::Listener] listener
    # @param [Struct] msg An AWS SQS message
    def initialize(listener, msg, listener_name, queue_url)
      @listener = listener
      # Regex raw JSON for a clue
      obj = case msg.body
            when /Subject[\\":\s]+ALARM/ then Message::Alarm
            when /Subject[\\":\s]+Auto Scaling/ then Message::AutoScaling
            else 
              msg.body[/Subject[\\":\s]+"([^"]+)"/]
              delete_message(listener, msg, listener_name, queue_url)
              raise Errors::UnknownSubject.new("Subject '#$1'")
            end
      begin
        @message = obj.new(
          message: msg,
          name: listener_name,
          queue_url: queue_url,
          aws_credentials: @listener.aws_credentials,
          region: @listener.region
        )
      rescue StandardError => e
        delete_message(listener, msg, listener_name, queue_url)
        raise e
      end
    end

    # Process an SQS message, by instantiating an instance of each action,
    # calling +run_before+, +run+, and +run_after+, and deleting the message.
    def process
      qurd_logger.info("Processing #{listener.name} " \
                       "action:#{message.action} " \
                       "subject:#{message.body.Subject}")

      if message.action
        instantiate_actions
        run_before
        run_action
        run_after
      end

      message.delete
    end

    # @private
    def inspect
      format('<Qurd::Processor:%x listener:%s message:%s>',
             object_id,
             listener.inspect,
             message.inspect
      )
    end

    private

    def delete_message(listener, msg, listener_name, queue_url)
      Message.new(
        message: msg,
        name: listener_name,
        queue_url: queue_url,
        aws_credentials: @listener.aws_credentials,
        region: @listener.region
      ).delete
    end

    def instantiate_actions
      @actions = qurd_configuration.actions[message.action].map do |klass|
        qurd_logger.debug("Instantiating #{klass}")
        klass.new(message)
      end
    end

    def run_before
      run_actions('run_before') do |action|
        action.send(:run_before)
      end
    end

    def run_action
      run_actions('run') do |action|
        action.send(message.action) if message.action
      end
    end

    def run_after
      run_actions('run_after') do |action|
        action.send(:run_after)
      end
    end

    def run_actions(desc, &block)
      @actions.each do |action|
        qurd_logger.time("#{desc} #{action}") do
          run(action, &block)
        end
      end
    end

    def run(action, &_block)
      qurd_logger.debug("Running #{action}")
      yield action
    rescue StandardError => e
      qurd_logger.error "#{action} raised #{e}"
      qurd_logger.error e.backtrace.join("\n")
      message.failed!(e)
    end
  end
end
