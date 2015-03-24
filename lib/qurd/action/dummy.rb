require 'qurd/action'
module Qurd
  class Action
    # Example of a sub-classed {#Qurd::Action}
    class Dummy < Action
      def self.configure(action)
        case action
        when 'launch' then qurd_logger.debug('launch')
        when 'launch_error' then qurd_logger.debug('launch_error')
        when 'terminate' then qurd_logger.debug('terminate')
        when 'terminate_error' then qurd_logger.debug('terminate_error')
        when 'test' then qurd_logger.debug('test')
        end
      end

      def launch
        message.context[:dummy] = true
        qurd_logger.debug('Qurd is debugging') if qurd_config.debug?
        qurd_logger.info("Received message #{message.inspect}")
      end
      alias_method :launch_error, :launch
      alias_method :terminate, :launch
      alias_method :terminate_error, :launch
      alias_method :test, :launch
    end
  end
end
