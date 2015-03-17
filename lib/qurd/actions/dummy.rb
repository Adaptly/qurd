module Qurd
  module Actions
    class Dummy
      extend Qurd::Mixins::Configuration
      def self.run(message)
        message.context[:dummy] = true
        qurd_logger.debug("Qurd is debugging") if qurd_config.debug?
        qurd_logger.info("Received message #{message.inspect}")
      end
    end
  end
end
