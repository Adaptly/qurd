require 'test_helper'
describe Qurd::Action do
  include WebMockStubs
  class TestActionClass < Qurd::Action; end

  describe 'class' do
    def setup
      aws_sqs_list_queues
      aws_sqs_set_queue_attributes
      aws_sqs_receive_message 'test/responses/aws/sqs-receive-message-1-launch.xml'
      Qurd::Configuration.instance.configure('test/inputs/qurd.yml')
    end
    let(:subject) { TestActionClass }

    it 'includes configuration mixin' do
      %w(qurd_config qurd_configuration qurd_logger qurd_logger!).each do |m|
        _(subject).must_respond_to m
      end
    end

    it 'includes aws_client mixin' do
      _(subject).must_respond_to :aws_client
    end

    describe '#configure' do
      it 'logs something' do
        mock = Minitest::Mock.new
        mock.expect :debug, nil, ['Nothing to do']
        subject.stub :qurd_logger, mock do
          subject.configure('launch')
        end
        mock.verify
      end
    end
  end

  describe 'instance' do
    def setup
      aws_sqs_list_queues
      aws_sqs_set_queue_attributes
      aws_sqs_receive_message 'test/responses/aws/sqs-receive-message-1-launch.xml'
      Qurd::Configuration.instance.configure('test/inputs/qurd_chef.yml')
    end
    let(:sqs_client) { Aws::SQS::Client.new(region: 'us-west-2') }
    let(:queue_url) { 'https://sqs.us-west-2.amazonaws.com/123456890/test2-ScalingNotificationsQueue-HPPYDAYSAGAI1' }
    let(:sqs_message) { sqs_client.receive_message(queue_url: queue_url).messages.first }
    let(:qurd_message) { Qurd::Message.new(message: sqs_message, region: 'us-west-2', aws_credentials: Aws::Credentials.new('a', 'b')) }
    let(:subject) { TestActionClass.new(qurd_message) }

    it 'includes configuration mixin' do
      %w(qurd_config qurd_configuration qurd_logger qurd_logger!).each do |m|
        _(subject).must_respond_to m
      end
    end

    it 'includes aws_client mixin' do
      _(subject).must_respond_to :aws_client
    end

    describe '#new' do
      it 'raises Qurd::Action::InvalidMessage' do
        _(lambda do
          TestActionClass.new(Object.new)
        end).must_raise Qurd::Action::InvalidMessage
      end

      it 'sets various ivars' do
        _(subject.message).must_equal qurd_message
        _(subject.context).must_equal qurd_message.context
        _(subject.instance_variable_get(:@message)).must_equal subject.message
        _(subject.instance_variable_get(:@context)).must_equal subject.context
      end
    end

    %w[aws_credentials instance chef_client chef_node failed! failed? 
       instance_id instance_name name region].each do |method|
      it "responds to #{method}" do
        aws_ec2_describe_instances 'test/responses/aws/ec2-describe-instances-1.xml'
       _(subject.send(method)).must_equal qurd_message.send(method)
      end
    end

    %w[launch launch_error terminate terminate_error test].each do |action|
      describe "##{action}" do
        it 'raises RuntimeError' do
          _(lambda do
            subject.send action
          end).must_raise RuntimeError
        end
      end
    end

    describe '#run_after' do
      it 'logs a message' do
        mock = Minitest::Mock.new
        mock.expect :debug, nil, ['Nothing to do']
        subject.stub :qurd_logger, mock do
          subject.run_after
        end
        mock.verify
      end
    end

    describe '#run_before' do
      it 'logs a message' do
        mock = Minitest::Mock.new
        mock.expect :debug, nil, ['Nothing to do']
        subject.stub :qurd_logger, mock do
          subject.run_before
        end
        mock.verify
      end
    end
  end
end
