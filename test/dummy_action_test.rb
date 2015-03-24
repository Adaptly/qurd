require 'test_helper'
describe Qurd::Action::Dummy do
  include WebMockStubs

  describe 'class' do
    def setup
      aws_sqs_list_queues
      aws_sqs_set_queue_attributes
      Qurd::Configuration.instance.configure('test/inputs/qurd.yml')
    end
    let(:subject) { Qurd::Action::Dummy }

    describe '#configure' do
      %w(launch launch_error terminate terminate_error test).each do |action|
        it "logs '#{action}'" do
          aws_sqs_receive_message "test/responses/aws/sqs-receive-message-1-#{action}.xml"
          mock = Minitest::Mock.new
          mock.expect :debug, nil, [action]
          subject.stub :qurd_logger, mock do
            subject.configure(action)
          end
          mock.verify
        end
      end
    end
  end

  describe 'instance' do
    def setup
      aws_sqs_list_queues
      aws_sqs_set_queue_attributes
      aws_ec2_describe_instances 'test/responses/aws/ec2-describe-instances-1.xml'
      Qurd::Configuration.instance.configure('test/inputs/qurd.yml')
    end
    let(:sqs_client) { Aws::SQS::Client.new(region: 'us-west-2') }
    let(:queue_url) { 'https://sqs.us-west-2.amazonaws.com/123456890/test2-ScalingNotificationsQueue-HPPYDAYSAGAI1' }
    let(:sqs_message) { sqs_client.receive_message(queue_url: queue_url).messages.first }
    let(:qurd_message) { Qurd::Message.new(message: sqs_message, region: 'us-west-2', aws_credentials: Aws::Credentials.new('a', 'b')) }
    let(:subject) { Qurd::Action::Dummy.new(qurd_message) }

    %w[launch launch_error terminate terminate_error test].each do |action|
      describe "##{action}" do
        it 'sets dummy context' do
          aws_sqs_receive_message "test/responses/aws/sqs-receive-message-1-#{action}.xml"
          subject.send action
          subject.context[:dummy].must_equal true
        end
      end
    end
  end
end
