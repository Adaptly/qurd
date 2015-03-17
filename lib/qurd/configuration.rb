module Qurd
  class Configuration
    include Singleton
    # @!attribute [r] config
    #   @!method dry_run
    #   @!method daemonize
    #   @!method pid_file
    #   @!method wait_time
    #   @!method visibility_timeout
    #   @!method log_file
    #   @!method log_level
    #   @!method accounts
    #   @!method actions
    #   @return [Hashie::Mash] the config YAML as a Mash
    # @!attribute [r] logger
    #   @return [Cabin::Channel] the logger
    # @!attribute [r] accounts
    #   @!method sqs
    #   @!method aws_access_key_id
    #   @!method aws_secret_access_key
    #   @!method region
    #   @!method queues
    #   @!method wait_time
    #   @!method visibility_timeout
    #   @return [Array<Hashie::Mash>] the accounts and queues to monitor
    # @!attribute [r] actions
    #   @!method start
    #   @!method stop
    #   @!method terminate
    #   @return [Hashie::Mash] the actions for each queue
    attr_reader :config, :logger, :accounts, :actions

    # Configure Qurd
    # @param [String] config_path The path to the config file, default
    # +/etc/qurd/config.yml+
    def configure(config_path)
      config_path = config_path || "/etc/qurd/config.yml"
      @config = Hashie::Mash.new YAML.load(File.read(config_path))
      @actions = Hashie::Mash.new({})
      @sqs_queues = {}
      @config.pid_file ||= "/var/run/qurd.pid"
      @config.daemonize = !ENV['A5Y_ENV'].nil? if @config.daemonize.nil?
      @config.dry_run = get_or_default(@config, :dry_run, false)
      @config.wait_time = get_or_default(@config, :wait_time, "10")
      @config.visibility_timeout = get_or_default(@config, :visibility_timeout, "30")

      configure_logger
      configure_accounts
      configure_queues
      configure_actions
    end

    # Determine if the daemon is running in debug mode
    # @return [TrueClass,FalseClass]
    def debug?
      config.log_level == "debug"
    end

    # Log an error and raise an exception
    # @param [String] msg The error and exception message
    # @param [Exception] e The exception to raise
    def logger!(msg, e = ::RuntimeError)
      logger.error msg
      raise e, msg
    end

    private

    # Convert strings to objects
    def configure_actions
      %w[launch stop terminate].each do |action|
        @actions[action] = []
      end

      missing = config.actions.inject([]) do |missing, mod|
        return missing unless mod[1]
        logger! "Action types must be an array" unless mod[1].kind_of?(Array)
        mod[1].each do |klass|
          begin
            @actions[mod[0]] << Object.const_get(klass)
            logger.debug("Found action #{mod[0]} #{@actions[mod[0]].last}")
          rescue NameError
            missing << klass
          end
        end

        missing
      end

      logger! "Class undefined for actions: #{missing.join(", ")}" if missing.any?
    end

    # Configure Cabin and Aws logging
    def configure_logger
      @logger = Cabin::Channel.new
      if config.daemonize
        path = config.log_file || "/var/log/apps/qurd/qurd.log"
        file = open(path, "w")
        @logger.subscribe(file)
        @logger.level = (config.log_level || :info).to_sym
      else
        @logger.level = (config.log_level || :debug).to_sym
        @logger.subscribe(STDOUT)
      end

      # TODO figure out why debugging causes Cabin to die
      # Seems like Cabin is having problems with the XML output of the Aws logger
      # /Users/pchampon/.rbenv/versions/2.1.2/lib/ruby/2.1.0/net/http.rb:1535:in `D': undefined method `<<' for #<Cabin::Channel:0x007f9a79570a60> (NoMethodError)
      Aws.config[:logger] = @logger
      Aws.config[:http_wire_trace] = debug?

      @logger.debug("Logging configured")
    end

    def get_or_default(obj, method, default)
      obj.send(method).nil? ? default : obj.send(method).to_s
    end

    # Configure sqs clients and queues
    def configure_accounts
      @accounts = []
      config.accounts.each do |name, acct|
        verify_account!(name, acct)
        creds = Aws::Credentials.new(
          acct.aws_access_key_id,
          acct.aws_secret_access_key
        )
        @sqs = Aws::SQS::Client.new(credentials: creds, region: acct.region)
        @accounts << Hashie::Mash.new({
          name: name,
          sqs: @sqs,
          ec2: Aws::EC2::Client.new(credentials: creds, region: acct.region),
          queues: convert_queues(acct.queues),
          wait_time: get_or_default(acct, :wait_time, config.wait_time),
          visibility_timeout: get_or_default(acct, :visibility_timeout, config.visibility_timeout),
        })
        logger.info("Configured #{name}: #{@accounts.last}")
      end
    end

    # Convert a regex string to a regex, including modifiers
    # @param [String] r String form of the regex
    # @return [Regexp] The compiled regex
    # @example With modifier
    #   Qurd::Configuration.parse_regex("/foo/i")
    def parse_regex(r)
      args = 0
      # /foo/ or /foo/i
      m = r.match %r{^/(.*)/([a-z]*)$}
      logger.debug("Found re: #{m[0]} 1: #{m[1]} 2: #{m[2]}")
      if m[2]
        m[2].each_byte do |c|
          args |= case c.chr
                  when 'i' then Regexp::IGNORECASE
                  when 'm' then Regexp::MULTILINE
                  when 'x' then Regexp::EXTENDED
                  when 'o' then 0
                  when 'e' then 16
                  else logger! "Unknown regex modifier #{c.chr}"
                  end
        end
      end
      regex = Regexp.new(m[1], args)
      logger.debug("Compiled regex #{regex}")
      queue_url regex
    end

    # Find the SQS URL for a named queue or a regex
    # @param [String|Regexp] name the name or regex of a queue
    # @return [String|Array<String>]
    def queue_url(name)
      hash = @sqs.hash
      @sqs_queues[hash] ||= @sqs.list_queues.queue_urls
      if name.respond_to?(:match)
        url = @sqs_queues[hash].select{|url| url =~ name}
      else
        url = @sqs_queues[hash].find{|url| url =~ %r{/#{name}$/}}
      end
      logger.debug("Queue #{name} found #{url}")
      url
    end

    # Convert regexes to and strings to queue URLs
    # @param [Array<String>] queues An array of queues to monitor
    # @return [Array<String>] SQS URLs
    def convert_queues(queues)
      queues.map do |q|
        q[0] == '/' ? parse_regex(q) : queue_url(q)
      end.flatten
    end

    def verify_account!(name, acct)
      missing_keys = []
      %w[aws_access_key_id aws_secret_access_key region queues].each do |key|
        missing_keys << key if acct[key].nil? || acct[key].empty?
      end

      logger! "Account #{name} missing account keys: #{missing_keys.join(", ")}" if missing_keys.any?
    end

    def configure_queues
      accounts.each do |acct|
        acct.queues.each do |q|
          #acct.sqs.set_queue_attributes(
            #queue_url: q,
            #attributes: {
              #ReceiveMessageWaitTimeSeconds: acct.wait_time,
              #VisibilityTimeout: acct.visibility_timeout
            #}
          #)
        end
      end
    end
  end
end
