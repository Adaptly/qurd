require 'test_helper'
describe Qurd::Message do
  include WebMockStubs

  let(:sqs_client) { Aws::SQS::Client.new(region: 'us-west-2') }
  let(:queue_url) { 'https://sqs.us-west-2.amazonaws.com/123456890/test2-ScalingNotificationsQueue-HPPYDAYSAGAI1' }
  let(:sqs_message) { sqs_client.receive_message(queue_url: queue_url).messages.first }
  let(:subject) do
    Qurd::Message.new(
      message: sqs_message,
      aws_credentials: Aws::Credentials.new('abc', 'def'),
      region: 'us-west-2')
  end

  describe '#add_accessor' do
    it 'adds getter and setter methods' do
      methods = [:test_method, :test_method=]
      methods.each do |method|
        t = Qurd::Message.instance_methods.include?(method)
       _( t).must_equal false
      end
      Qurd::Message.add_accessor(:test_method)
      methods.each do |method|
        t = Qurd::Message.instance_methods.include?(method)
       _( t).must_equal true
      end
    end
  end

  describe 'configuration mixin' do
    it 'responds to #qurd_config' do
      aws_sqs_receive_message 'test/responses/aws/sqs-receive-message-1-launch.xml'
      _(subject).must_respond_to :qurd_config
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
      get_ivar(:@aws_credentials).must_be_kind_of Aws::Credentials
      # changes between #receive_message calls
      get_ivar(:@context).must_be_kind_of Cabin::Context
      get_ivar(:@region).must_equal 'us-west-2'
      get_ivar(:@failed).must_equal false
      get_ivar(:@exceptions).must_equal []
    end
  end

  describe '#body' do
    def setup
      aws_sqs_receive_message 'test/responses/aws/sqs-receive-message-1-launch.xml'
    end
    it 'converts json to a mash' do
      _(subject.body).must_be_kind_of Hashie::Mash
    end
  end

  describe '#message' do
    def setup
      aws_sqs_receive_message 'test/responses/aws/sqs-receive-message-1-launch.xml'
    end
    it 'converts json to a mash' do
      _(subject.message).must_be_kind_of Hashie::Mash
    end
  end

  describe '#receipt_handle' do
    def setup
      aws_sqs_receive_message 'test/responses/aws/sqs-receive-message-1-launch.xml'
    end
    it 'retrieves the message\'s receipt handle' do
      _(subject.receipt_handle).must_equal 'foobar=='
    end
  end

  describe '#message_id' do
    def setup
      aws_sqs_receive_message 'test/responses/aws/sqs-receive-message-1-launch.xml'
    end
    it 'retrieves the message\'s message id' do
      _(subject.message_id).must_be_kind_of String
    end
  end

  describe '#failed!' do
    def setup
      aws_sqs_receive_message 'test/responses/aws/sqs-receive-message-1-launch.xml'
    end

    it 'records an exception' do
      expected = Exception.new('foo')
      subject.failed! expected
      _(subject.exceptions).must_equal [expected]
    end

    it 'set failed to true' do
      subject.failed!
      _(subject.instance_variable_get(:@failed)).must_equal true
    end
  end

  describe '#failed?' do
    def setup
      aws_sqs_receive_message 'test/responses/aws/sqs-receive-message-1-launch.xml'
    end

    it 'is false' do
      _(subject.failed?).must_equal false
    end

    it 'is true' do
      subject.failed!
      _(subject.failed?).must_equal true
    end
  end

  describe '#action' do
    %w[launch launch_error terminate terminate_error test].each do |action|
      it "is #{action}" do
        aws_sqs_receive_message "test/responses/aws/sqs-receive-message-1-#{action}.xml"
        _(subject.action).must_equal action
      end
    end

    it 'is nil' do
      aws_sqs_receive_message 'test/responses/aws/sqs-receive-message-1-other.xml'
      _(subject.action).must_equal nil
    end
  end

  describe '#instance' do
    def setup
      aws_sqs_receive_message 'test/responses/aws/sqs-receive-message-1-launch.xml'
    end

    it 'returns an instance' do
      aws_ec2_describe_instances 'test/responses/aws/ec2-describe-instances-1.xml'
      _(subject.instance).must_be_kind_of Struct
    end

    it 'returns nil' do
      aws_ec2_describe_instances 'test/responses/aws/ec2-describe-instances-0.xml'
      _(subject.instance).must_equal nil
    end

    it 'raises Aws::EC2::Errors::InvalidInstanceIDNotFound' do
      aws_ec2_describe_instances 'test/responses/aws/ec2-describe-instances-0.xml', 500
      _(lambda {
        subject.instance(0)
      }).must_raise Aws::EC2::Errors::InvalidInstanceIDNotFound
    end
  end

  describe '#instance_name' do
    def setup
      aws_sqs_receive_message 'test/responses/aws/sqs-receive-message-1-launch.xml'
    end

    it 'returns an instance name' do
      aws_ec2_describe_instances 'test/responses/aws/ec2-describe-instances-1.xml'
      _(subject.instance_name).must_equal 'test-414.staging.example.com'
    end

    it 'returns nil' do
      aws_ec2_describe_instances 'test/responses/aws/ec2-describe-instances-0.xml'
      _(subject.instance_name).must_equal nil
    end

  end

  describe '#aws_instance' do
    it 'returns nil, if instance_id is nil' do
      aws_sqs_receive_message 'test/responses/aws/sqs-receive-message-1-launch.xml'
      subject.stub :instance_id, nil do
        _(subject.send(:aws_instance)).must_equal nil
      end
    end
  end

end
