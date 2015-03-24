module Qurd
  module Mixins
    # Mixin the {#Qurd::Configuration} singleton
    module Configuration
      # Get the Qurd::Configuration singleton
      # @return [Qurd::Configuration]
      def qurd_config
        @qurd_config ||= Qurd::Configuration.instance
      end

      # Get the parsed configuration for the daemon
      # @return [Hashie::Mash]
      def qurd_configuration
        qurd_config.config
      end

      # Get the logger
      # @return [Logger]
      def qurd_logger
        qurd_config.logger
      end

      # Log an error and raise an exception
      def qurd_logger!(*a)
        qurd_config.logger!(*a)
      end
    end
  end
end
