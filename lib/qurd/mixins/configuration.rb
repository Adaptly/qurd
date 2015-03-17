module Qurd
  module Mixins
    module Configuration
      def qurd_config
        @qurd_config ||= Qurd::Configuration.instance
      end

      def qurd_configuration
        qurd_config.config
      end

      def qurd_logger
        qurd_config.logger
      end

      def qurd_logger!(*a)
        qurd_config.logger!(*a)
      end

      def qurd_accounts
        qurd_config.accounts
      end

      def qurd_actions
        qurd_config.actions
      end
    end
  end
end

