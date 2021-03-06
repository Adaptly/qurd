# rubocop:disable ClassLength
# Gem module
module Qurd
  # Provide an interface for interacting with configured queues and AWS.
  class Listener
    include Qurd::Mixins::AwsClients
    include Qurd::Mixins::Configuration

    # @!attribute aws_credentials [r]
    #   The AWS credentials for the account
    #   @return [Aws::Credentials]
    # @!attribute message [r]
    #   The message reveived
    #   @return [Qurd::Message]
    # @!attribute name [r]
    #   The name of the executor
    #   @return [String]
    # @!attribute queues [r]
    #   An array of AWS SQS URLs for the account
    #   @return [Array<String>]
    # @!attribute region [r]
    #   The AWS region for the account
    #   @return [String]
    # @!attribute visibility_timeout [r]
    #   @return [String]
    # @!attribute wait_time [r]
    #   @return [String]
    attr_reader :aws_credentials,
                :message,
                :name,
                :queues,
                :region,
                :visibility_timeout,
                :wait_time

    # @param [Hash] attrs
    # @option attrs [Aws::Credentials] :aws_credentials
    # @option attrs [String] :name
    # @option attrs [Array<String|Regexp>] :queues An array of SQS names
    #   and Regexps
    # @option attrs [String] :region
    # @option attrs [String] :visibility_timeout
    # @option attrs [String] :wait_time
    def initialize(attrs = {})
      @aws_credentials = attrs[:aws_credentials]
      @name = attrs[:name]
      @region = attrs[:region]
      @visibility_timeout = attrs[:visibility_timeout]
      @wait_time = attrs[:wait_time]
      @queues = convert_queues attrs[:queues]
      configure_queues
    end

    # Create a thread for each queue URL, a context denoting the listener name
    # and the queue URL.
    # @param [Proc] _block the proc each thread should run
    # @yieldparam [String] url the url of the queue
    # @yieldparam [Cabin::Context] ctx the logging context
    def queue_threads(&_block)
      queues.map do |qurl|
        @mutex = Mutex.new
        @counter = Hashie::Mash.new({thread_timeouts: 0, aws_service_errors: 0, successes: 0, failures: 0, messages: 0})

        qurd_logger.debug("Creating thread for #{qurl}")
        Thread.new(qurl) do |url|
          ctx = qurd_config.get_context(name: name, queue_name: url[/([^\/]+)$/])
          qurd_logger.debug('Thread running')
          yield url, ctx
        end
      end
    end

    # Create one thread per +queue+, receive messages from it and process each
    # message received
    # @return [Array<Thread>]
    def listen
      threads = queue_threads do |qurl, _context|
        loop do
          begin
            msgs = aws_client(:SQS).receive_message(
              queue_url: qurl,
              wait_time_seconds: wait_time,
              visibility_timeout: visibility_timeout
            )
            threads = process_messages(qurl, msgs)
            joins = threads.map do |thread|
              thread.join(qurd_configuration.listen_timeout)
            end
            if joins.compact.count != threads.count
              nthreads = threads.count - joins.compact.count
              lock_counter { @counter.thread_timeouts += nthreads }
              qurd_logger.warn('Some threads timed out')
            end
          rescue Aws::Errors::ServiceError => e
            lock_counter { @counter.aws_service_errors += 1 }
            qurd_logger.error("Aws raised #{e}")
          end
        end
      end
      threads << stats_thread
    end

    # @private
    def inspect
      format('<Qurd::Listener:%x name:%s>',  object_id, name)
    end

    private

    def stats_thread
      Thread.new do
        loop do
          sleep(qurd_configuration.stats_interval)
          lock_counter { qurd_logger.info("STATS", @counter) }
        end
      end
    end

    def lock_counter(&_block)
      @mutex.synchronize {
        begin
          yield
        rescue ThreadError => e
          @mutex.sleep(0.1)
          qurd_logger.debug("ThreadError: #{e}")
          retry
        end
      }
    end

    def process_messages(qurl, msgs)
      lock_counter { @counter.messages += msgs.messages.count }
      msgs.messages.map do |msg|
        Thread.new(msg) do |m|
          qurd_logger.debug("Found message #{msg}")
          begin
            r = Processor.new self, m, name, qurl
            r.process
            lock_counter { 
              r.message.failed? ?
              @counter.failures += 1 :
              @counter.successes += 1
            }
          rescue Qurd::Processor::Errors::UnknownSubject => e
            qurd_logger.error("Unprocessable SQS body #{e}")
            lock_counter {
              @counter.failures += 1
            }
          end
        end
      end
    end

    def configure_queues
      threads = configure_queues_threads
      joins = threads.map do |thread|
        thread.join(qurd_configuration.sqs_set_attributes_timeout)
      end

      qurd_logger! 'One or more threads timed out' \
        if joins.compact.count != threads.count
    end

    def configure_queues_threads
      queue_threads do |q, _context|
        qurd_logger.debug("Setting wait_time:#{wait_time} " \
                          "visibility_timeout:#{visibility_timeout} #{q}")
        begin
          aws_client(:SQS).set_queue_attributes(
            queue_url: q,
            attributes: {
              ReceiveMessageWaitTimeSeconds: wait_time,
              VisibilityTimeout: visibility_timeout
            }
          )
        rescue Aws::SQS::Errors::QueueDoesNotExist => e
          qurd_logger.error("SQS raised #{e}")
          Thread.terminate
        rescue Aws::SQS::Errors::ServiceError => e
          qurd_logger.error("SQS raised #{e}")
          raise e
        end
      end
    end

    # Convert a regex string to a regex, including modifiers
    # @param [String] r String form of the regex
    # @return [Regexp] The compiled regex
    # @example With modifier
    #   Qurd::Configuration.parse_regex("/foo/i")
    def parse_regex(r)
      # /foo/ or /foo/i
      m = r.match %r{\A/(.*)/([a-z]*)\Z}mx
      qurd_logger.debug("Found re: #{m[0]} 1: #{m[1]} 2: #{m[2]}")
      args = modifier2int(m[2])
      regex = Regexp.new(m[1], args)
      qurd_logger.debug("Compiled regex #{regex}")
      queue_url regex
    end

    def modifier2int(str)
      args = 0
      str.each_byte do |c|
        args |= case c.chr
                when 'i' then Regexp::IGNORECASE
                when 'm' then Regexp::MULTILINE
                when 'x' then Regexp::EXTENDED
                when 'o' then 0
                when 'e' then 16
                else qurd_logger! "Unknown regex modifier #{c.chr}"
                end
      end
      args
    end

    # Find the SQS URL for a named queue or a regex
    # @overload queue_url(name)
    #   @param [String] name The AWS SQS name
    #   @return [String] AWS SQS URL
    #
    # @overload queue_url(name)
    #   @param [Regexp] name regex of a queue name
    #   @return [Array<String>]
    def queue_url(name)
      @sqs_queues ||= aws_client(:SQS).list_queues.queue_urls

      if name.respond_to?(:upcase)
        url = @sqs_queues.find { |u| u[/([^\/]+$)/] == name }
      else
        url = @sqs_queues.select { |u| u =~ name }
      end
      qurd_logger.debug("Queue #{name} found '#{url}'")
      qurd_logger.warn("No queue found for '#{name}'") if url.nil? || url.empty?
      url
    rescue Aws::SQS::Errors::ServiceError => e
      qurd_logger.error("SQS raised #{e}")
      raise e
    end

    # Convert regexes to and strings to queue URLs
    # @param [Array<String>] queues An array of queues to monitor
    # @return [Array<String>] SQS URLs
    def convert_queues(queues)
      queues.map do |q|
        q[0] == '/' ? parse_regex(q) : queue_url(q)
      end.flatten.compact
    end
  end
end
