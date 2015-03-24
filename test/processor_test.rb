require 'test_helper'
describe Qurd::Processor do
  include WebMockStubs

  let(:sqs_client) { Aws::SQS::Client.new(region: 'us-west-2') }
  let(:queue_url) { 'https://sqs.us-west-2.amazonaws.com/123456890/test2-ScalingNotificationsQueue-HPPYDAYSAGAI1' }
  let(:sqs_message) { sqs_client.receive_message(queue_url: queue_url).messages.first }
  let(:listener) do
    Qurd::Listener.new(
      queues: [],
      aws_credentials: Aws::Credentials.new('abc', 'def'),
      region: 'us-west-2',
      name: 'staging',
      visibility_timeout: '0',
      wait_time: '0'
  )
  end
  let(:subject) { Qurd::Processor.new(listener, sqs_message, 'staging', queue_url) }

  describe 'configuration mixin' do
    it 'responds to #qurd_config' do
      aws_sqs_receive_message 'test/responses/aws/sqs-receive-message-1-launch.xml'
      subject.must_respond_to :qurd_config
    end
  end

  describe '#new' do
    def setup
      aws_sqs_receive_message 'test/responses/aws/sqs-receive-message-1-launch.xml'
    end

    def get_ivar(name)
      subject.instance_variable_get name.to_sym
    end

    it 'sets various ivars' do
      get_ivar(:@listener).must_equal listener
      get_ivar(:@message).must_be_kind_of Qurd::Message
    end
  end
end
