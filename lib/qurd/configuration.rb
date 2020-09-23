# rubocop:disable ClassLength
module Qurd
  # Parse a configuration file, create a logger and various data structures
  class Configuration
    include Singleton
    include Mixins::ConfigurationHelpers
    # @!attribute [r] config
    #   Configuration options, ie
    #   +aws_credentials+, +auto_scaling_queues+, +actions+, +daemonize+,
    #   +dry_run+, +listen_timeout+, +log_file+, +log_level+, +pid_file+,
    #   +save_failures+, +stats_interval+, +sqs_set_attributes_timeout+,
    #   +visibility_timeout+, +wait_time+.
    #   Additional configuration keys include +listeners+.
    #   @return [Hashie::Mash] the config YAML as a Mash
    # @!attribute [r] logger
    #   The logger
    #   @return [Cabin::Channel]
    attr_reader :config, :logger

    # Initialize Qurd
    # @param [String] config_path The path to the config file, default
    #   +/etc/qurd/config.yml+
    def init(config_path)
      config_path ||= '/etc/qurd/config.yml'
      @config = Hashie::Mash.new YAML.load(File.read(config_path))
      @sqs_queues = {}
      @config.daemonize = false if @config.daemonize.nil?
      @config.dry_run = get_or_default(@config, :dry_run, false)
      @config.pid_file ||= '/var/run/qurd/qurd.pid'
      @config.save_failures = get_or_default(@config, :save_failures, true)
      @queues = []
      @aws_credentials = []
      st = get_or_default(@config, :sqs_set_attributes_timeout, 10, :to_f)
      si = get_or_default(@config, :stats_interval, 600, :to_i)
      vt = get_or_default(@config, :visibility_timeout, 300, :to_s)
      wt = get_or_default(@config, :wait_time, 20, :to_s)
      lt = get_or_default(@config, :listen_timeout, vt, :to_f)
      @config.stats_interval = si
      @config.visibility_timeout = vt
      @config.wait_time = wt
      @config.sqs_set_attributes_timeout = st
      @config.listen_timeout = lt
      %w[launch launch_error terminate terminate_error test].each do |action|
        @config.actions[action] ||= []
      end

      configure_logger
    end

    # Configure Qurd
    # @param [String] config_path The path to the config file, default
    #   +/etc/qurd/config.yml+
    def configure(config_path)
      init(config_path)
      mkdir_p_file!(@config.pid_file)

      configure_credentials
      configure_auto_scaling_queues
      configure_actions
    end

    # Determine if the daemon is running in debug mode
    # @return [Boolean]
    def debug?
      config.log_level == 'debug'
    end

    # Log an error and raise an exception
    # @param [String] msg The error and exception message
    # @param [Exception] e The exception to raise
    def logger!(msg, e = RuntimeError)
      logger.error msg
      fail e, msg
    end

    # Get a logging context and optionally initialize it
    # @param [Hash] attrs a hash of values to +merge+ into the context
    # @return [Cabin::Context]
    def get_context(attrs = {})
      ctx = logger.context
      attrs.each do |k, v|
        ctx[k] = v
      end
      ctx
    end

    private

    def configure_credentials
      if config.aws_credentials.nil? || config.aws_credentials.empty?
        creds = default_credentials
      else
        creds = config.aws_credentials.map do |cred|
          cred.options ||= {}
          case cred.type
          when 'assume_role_credentials'
            assume_role_credentials(cred)
          when 'credentials'
            credentials(cred)
          when 'shared_credentials'
            shared_credentials(cred)
          when 'instance_profile_credentials'
            instance_profile_credentials(cred)
          else qurd_logger! "Credential type unknown: '#{cred.type}'"
          end
        end
      end
      config.aws_credentials = Hash[creds]
    end

    # Convert strings to objects
    def configure_actions
      missing = config.actions.inject([]) do |ary, mod|
        action, klasses = mod
        return ary if klasses.nil?
        ctx = get_context(action: action)
        logger! 'Action types must be an array' unless klasses.is_a?(Array)
        klasses.map! do |klass|
          begin
            k = string2class(klass)
            k.configure(action)
            k
          rescue NameError, LoadError => e
            logger.error(e)
            ary << klass
          end
        end
        ctx.clear
        ary
      end

      m = missing.uniq.join(', ')
      logger! "Class undefined for actions: #{m}" if missing.any?
    end

    # Configure Cabin and Aws logging
    def configure_logger
      @logger = Cabin::Channel.new
      if config.log_file || config.daemonize
        path = config.log_file || '/var/log/qurd/qurd.log'
        mkdir_p_file!(path)
        config.log_file_io = open(path, 'w')
        @ruby_logger = Logger.new(config.log_file_io)
        @logger.level = (config.log_level || :info).to_sym
      else
        @logger.level = (config.log_level || :debug).to_sym
        @ruby_logger = Logger.new(STDOUT)
      end
      @logger.subscribe(@ruby_logger)

      Aws.config[:logger] = @ruby_logger
      Aws.config[:http_wire_trace] = debug?

      @logger.debug('Logging configured')
    end

    # Configure sqs clients and queues
    def configure_auto_scaling_queues
      config.keys.grep(/_queues$/).each do |queue|
        ary = config.send queue
        config.listeners = ary.map do |name, monitor|
          if (ary.nil? ||
               ary.empty?) &&
             config.aws_credentials.default
            creds = config.aws_credentials.default
            monitor.credentials = 'default'
          else
            creds = config.aws_credentials[monitor.credentials]
          end
          verify_account!(name, monitor)
          logger!("Undefined credential: '#{monitor.credentials}'") unless creds
          vt = get_or_default(monitor, :visibility_timeout,
                              config.visibility_timeout, :to_s)
          wt = get_or_default(monitor, :wait_time, config.wait_time, :to_s)
          Listener.new(
            aws_credentials: creds,
            name: name,
            queues: monitor.queues,
            region: monitor.region,
            visibility_timeout: vt,
            wait_time: wt
          )
        end
      end
    end
  end
end
