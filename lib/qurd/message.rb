module Qurd
  class Message
    include Qurd::Mixins::Configuration
    attr_reader :message, :message_id, :body, :instance_id, :instance, :queue, :context

    def initialize(attrs={})
      @deleted = false
      @queue = attrs[:queue]
      @config = attrs[:config]
      @body = Hashie::Mash.new JSON.load(attrs[:message].body)
      @message = Hashie::Mash.new JSON.load(@body.Message)
      @instance_id = @message.EC2InstanceId
      @message_id = @body.MessageId

      @context = qurd_logger.context
      @context[:instance_id] = @instance_id
      @context[:message_id] = @message_id

      qurd_logger.info "Received #{@body.Subject}"
      qurd_logger.info "Cause #{@message.Cause}"
      qurd_logger.info "Event #{@message.Event}"
    end

    def process
      action = case message.Event
        when 'autoscaling:EC2_INSTANCE_LAUNCH' then 'launch'
        when 'autoscaling:EC2_INSTANCE_STOP' then 'stop'
        when 'autoscaling:EC2_INSTANCE_TERMINATE' then 'terminate'
      end
      qurd_logger.info("Action #{action}")
      action && qurd_actions[action].each do |action|
        action.run(self)
      end
      delete_message
    end

    def delete_message
      @deleted = true
      if qurd_configuration.dry_run
        qurd_logger.info "Dry run"
      else
        qurd_logger.info "Deleting"
        config.sqs.delete_message(queue_url: queue, receipt_handle: message_id)
      end
    end

    def instance
      return @instance if @instance_check
      @instance_check = config.ec2.describe_instances(instance_ids: [instance_id])
      @instance = res.reservations.first
    end

    def inspect
      "#<Qurd::Message:%x deleted:%s message_id:%s subject:%s cause:%s @instance_id:%s @instance:%s>" % 
        [object_id, 
         @deleted, 
         message_id, 
         body.Subject, 
         message.Cause, 
         instance_id, 
         instance
      ]
    end
  end
end
