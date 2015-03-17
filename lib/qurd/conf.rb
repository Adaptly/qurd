module Qurd
  module Mixins
    module Conf
      def config
        @config ||= Qurd::Configuration.instance
      end

      def configuration
        config.config
      end

      def logger
        config.logger
      end

      def logger!(*a)
        config.logger!(*a)
      end

      def accounts
        config.accounts
      end

      def actions
        config.actions
      end
    end
  end
end

