require 'test_helper'
describe Qurd::Message::Alarm do
  include WebMockStubs

  let(:sqs_client) { Aws::SQS::Client.new(region: 'us-west-2') }
  let(:queue_url) { 'https://sqs.us-west-2.amazonaws.com/123456890/test2-ScalingNotificationsQueue-HPPYDAYSAGAI1' }
  let(:sqs_message) { sqs_client.receive_message(queue_url: queue_url).messages.first }
  let(:subject) do
    Qurd::Message::Alarm.new(
      message: sqs_message,
      aws_credentials: Aws::Credentials.new('abc', 'def'),
      region: 'us-west-2')
  end

  describe '#add_accessor' do
    def setup
      aws_auto_scaling_describe_auto_scaling_groups
    end
    it 'adds getter and setter methods' do
      methods = [:test_method, :test_method=]
      methods.each do |method|
        t = Qurd::Message::AutoScaling.instance_methods.include?(method)
       _( t).must_equal false
      end
      Qurd::Message::AutoScaling.add_accessor(:test_method)
      methods.each do |method|
        t = Qurd::Message::AutoScaling.instance_methods.include?(method)
       _( t).must_equal true
      end
    end
  end

  describe 'configuration mixin' do
    def setup
      aws_auto_scaling_describe_auto_scaling_groups
    end
    it 'responds to #qurd_config' do
      aws_sqs_receive_message 'test/responses/aws/sqs-receive-message-1-cpu-terminate.xml'
      _(subject).must_respond_to :qurd_config
    end
  end

  describe '#new' do
    def setup
      aws_sqs_receive_message 'test/responses/aws/sqs-receive-message-1-cpu-terminate.xml'
      aws_auto_scaling_describe_auto_scaling_groups
    end

    def get_ivar(name)
      subject.instance_variable_get name.to_sym
    end

    it 'sets various ivars' do
      _(get_ivar(:@aws_credentials)).must_be_kind_of Aws::Credentials
      # changes between #receive_message calls
      _(get_ivar(:@context)).must_be_kind_of Cabin::Context
      _(get_ivar(:@region)).must_equal 'us-west-2'
      _(get_ivar(:@failed)).must_equal false
      _(get_ivar(:@exceptions)).must_equal []
    end
  end

  describe '#body' do
    def setup
      aws_sqs_receive_message 'test/responses/aws/sqs-receive-message-1-cpu-terminate.xml'
      aws_auto_scaling_describe_auto_scaling_groups
    end
    it 'converts json to a mash' do
      _(subject.body).must_be_kind_of Hashie::Mash
    end
  end

  describe '#message' do
    def setup
      aws_sqs_receive_message 'test/responses/aws/sqs-receive-message-1-cpu-terminate.xml'
      aws_auto_scaling_describe_auto_scaling_groups
    end
    it 'converts json to a mash' do
      _(subject.message).must_be_kind_of Hashie::Mash
    end
  end

  describe '#receipt_handle' do
    def setup
      aws_sqs_receive_message 'test/responses/aws/sqs-receive-message-1-cpu-terminate.xml'
      aws_auto_scaling_describe_auto_scaling_groups
    end
    it 'retrieves the message\'s receipt handle' do
      _(subject.receipt_handle).must_equal 'foobar=='
    end
  end

  describe '#message_id' do
    def setup
      aws_sqs_receive_message 'test/responses/aws/sqs-receive-message-1-cpu-terminate.xml'
      aws_auto_scaling_describe_auto_scaling_groups
    end
    it 'retrieves the message\'s message id' do
      _(subject.message_id).must_be_kind_of String
    end
  end

  describe '#instance_id' do
    def setup
      aws_sqs_receive_message 'test/responses/aws/sqs-receive-message-1-cpu-terminate.xml'
      aws_auto_scaling_describe_auto_scaling_groups
    end
    it 'retrieves the message\'s intsance id' do
      _(subject.instance_id).must_equal "i-06bc92c8b846611f3"
    end
  end

  describe '#auto_scaling_group_name' do
    def setup
      aws_auto_scaling_describe_auto_scaling_groups('test/responses/aws/autoscaling-describe-auto-scaling-group-name-2.xml')
    end
    # FIXME Dunno why this kept tripping web mock
    #it 'raises TooManyInstances' do
      #_(lambda {
        #subject.auto_scaling_group_name
      #}).must_raise Qurd::Message::Alarm::Errors::TooManyInstances
    #end
  end

  describe '#failed!' do
    def setup
      aws_sqs_receive_message 'test/responses/aws/sqs-receive-message-1-cpu-terminate.xml'
      aws_auto_scaling_describe_auto_scaling_groups
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
      aws_sqs_receive_message 'test/responses/aws/sqs-receive-message-1-cpu-terminate.xml'
      aws_auto_scaling_describe_auto_scaling_groups
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
    %w[terminate].each do |action|
      it "is #{action}" do
        aws_sqs_receive_message "test/responses/aws/sqs-receive-message-1-cpu-#{action}.xml"
        aws_auto_scaling_describe_auto_scaling_groups
        _(subject.action).must_equal action
      end
    end
  end

end
