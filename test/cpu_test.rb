require 'test_helper'
describe Qurd::Action::Cpu do
  include WebMockStubs
  def setup
    aws_sqs_list_queues
    aws_sqs_set_queue_attributes
    aws_sqs_receive_message 'test/responses/aws/sqs-receive-message-1-alarm-cpu.xml',
                            '/123456890/test2-AlarmQueue-C6C6L7II8QTM'
    ec2metadata
  end

  let(:sqs_client) { Aws::SQS::Client.new(region: 'us-west-2') }
  let(:queue_url) { 'https://sqs.us-west-2.amazonaws.com/123456890/test2-AlarmQueue-C6C6L7II8QTM' }
  let(:sqs_message) { sqs_client.receive_message(queue_url: queue_url).messages.first }
  let(:qurd_message) { Qurd::Message.new(message: sqs_message, region: 'us-west-2', aws_credentials: Aws::Credentials.new('a', 'b'), name: 'staging') }
          
  let(:subject) { Qurd::Action::Cpu.new(qurd_message) }

  describe '#configure' do
    it 'adds the Qurd::Message accessors chef_node, chef_client' do
      Qurd::Configuration.instance.init('test/inputs/qurd_cpu.yml')
      Qurd::Action::Cpu.configure('launch')
    end

  end

  describe '#run_before' do
    def setup
      aws_sqs_list_queues
      aws_sqs_set_queue_attributes
      aws_sqs_receive_message 'test/responses/aws/sqs-receive-message-1-alarm-cpu.xml',
                              '/123456890/test2-AlarmQueue-C6C6L7II8QTM'
      ec2metadata
      Qurd::Configuration.instance.configure('test/inputs/qurd_cpu.yml')
    end

  end

  describe '#terminate' do
    def setup
      aws_auto_scaling_describe_auto_scaling_groups
      aws_ec2_terminate_instances
      aws_sqs_list_queues
      aws_sqs_set_queue_attributes
      aws_sqs_receive_message 'test/responses/aws/sqs-receive-message-1-alarm-cpu.xml',
                              '/123456890/test2-AlarmQueue-C6C6L7II8QTM'
      ec2metadata
      Qurd::Configuration.instance.configure('test/inputs/qurd_cpu.yml')
    end
    let(:mock) { Minitest::Mock.new }

    it 'saves a node; dry_run' do
      mock.expect :debug, nil, ['Dry run; would delete']

      subject.stub :qurd_logger, mock do
        Qurd::Configuration.instance.config.dry_run = true
        subject.terminate
      end
      mock.verify
    end

    it 'destroys a node; not dry_run; not failed' do
      aws_route53_change_resource_record_sets
      Qurd::Configuration.instance.config.dry_run = false
      subject.terminate
    end

  end

  describe '#test' do
    def setup
      aws_sqs_list_queues
      aws_sqs_set_queue_attributes
      aws_sqs_receive_message 'test/responses/aws/sqs-receive-message-1-alarm-cpu.xml',
                              '/123456890/test2-AlarmQueue-C6C6L7II8QTM'
      ec2metadata
      Qurd::Configuration.instance.configure('test/inputs/qurd_cpu.yml')
    end
    let(:mock) { Minitest::Mock.new }

    it 'logs Test' do
      mock.expect :info, nil, ['Test']
      subject.run_before
      subject.stub :qurd_logger, mock do
        subject.test
      end
      mock.verify
    end
  end
end
