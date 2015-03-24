module Qurd
  module Mixins
    # Helpers for managing configuration details
    module ConfigurationHelpers
      private

      def get_or_default(obj, method, default, cast = nil)
        val = obj.send(method).nil? ? default : obj.send(method)
        cast.nil? ? val : val.send(cast)
      end

      def verify_account!(name, monitor)
        missing_keys = []
        %w(credentials region queues).each do |key|
          missing_keys << key if monitor[key].nil? || monitor[key].empty?
        end

        keys = missing_keys.join(', ')
        logger! "Account #{name} missing keys: #{keys}" unless keys.empty?
      end

      def mkdir_p_file!(path)
        return if File.exist?(path) && File.writable?(path)
        dirname = File.dirname(path)
        FileUtils.mkdir_p dirname
        logger! "Directory not writable: #{dirname}" \
          unless File.writable?(dirname)
      end

      def default_credentials
        [['default',
          Aws::InstanceProfileCredentials.new(http_open_timeout: 1,
                                              http_read_timeout: 1,
                                              retries: 1
        )]]
      end

      def assume_role_credentials(cred)
        opts = {}
        %w(role_arn role_session_name policy duration_seconds
           external_id).each do |key|
          opts[key.to_sym] = cred.options[key] if cred.options.key?(key)
        end
        [cred.name, Aws::AssumeRoleCredentials.new(opts)]
      end

      def credentials(cred)
        opts = [cred.options.access_key_id,
                cred.options.secret_access_key,
                cred.options.session_token]
        [cred.name, Aws::Credentials.new(*opts)]
      end

      def shared_credentials(cred)
        opts = {
          profile_name: cred.options.profile_name
        }
        opts[:path] = cred.options.path if cred.options.key?(:path)
        [cred.name, Aws::SharedCredentials.new(opts)]
      end

      def instance_profile_credentials(cred)
        opts = {}
        %w(retries ip_address port http_open_timeout http_read_timeout
           delay http_debug_output).each do |key|
          opts[key.to_sym] = cred.options[key] if cred.options.key?(key)
        end
        [cred.name, Aws::InstanceProfileCredentials.new(opts)]
      end

      def string2class(klass)
        require klass.underscore
        obj = Object.const_get(klass)
        logger.debug("Found action #{klass}")
        obj
      end
    end
  end
end
