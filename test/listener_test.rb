require 'test_helper'
describe Qurd::Listener do
  include WebMockStubs

  let(:queue_url) { 'https://sqs.us-west-2.amazonaws.com/123456890/test2-ScalingNotificationsQueue-HPPYDAYSAGAI1' }
  let(:queue_name) { queue_url[/([^\/]+$)/] }
  let(:subject) do
    Qurd::Listener.new(
      aws_credentials: Aws::Credentials.new('abc', 'def'),
      region: 'us-west-2',
      name: 'staging',
      visibility_timeout: '1',
      wait_time: '0',
      queues: [queue_name]
  )
  end

  def setup
    aws_sqs_list_queues
    aws_sqs_set_queue_attributes
    aws_sqs_receive_message 'test/responses/aws/sqs-receive-message-1-launch.xml'
    Qurd::Configuration.instance.init('test/inputs/qurd.yml')
  end

  describe '#listen' do
    it 'is complicated' do
      skip 'hmmm..'
    end
  end

  describe '#queue_threads' do
    it 'creates one thread per queue' do
      threads = subject.queue_threads do |url, ctx|
        _(url).must_equal queue_url
        _(ctx).must_be_kind_of Cabin::Context
      end
      _(threads.count).must_equal 1
      _(threads.first).must_be_kind_of Thread
    end
  end

  describe '#configure_queues' do
    it 'is complicated' do
      skip 'hmmm..'
    end
  end

  describe '#new' do
    def get_ivar(name)
      subject.instance_variable_get name.to_sym
    end
    let(:attrs) do
      creds = Aws::Credentials.new('abc', 'def')
      {
        aws_credentials: creds,
        name: 'staging',
        queues: [],
        region: 'us-west-2',
        visibility_timeout: '0',
        wait_time: '1'
      }
    end
    let(:subject) { Qurd::Listener.new(attrs) }
    it 'sets ivars' do
      get_ivar(:@aws_credentials).must_be_kind_of Aws::Credentials
      get_ivar(:@name).must_equal 'staging'
      get_ivar(:@visibility_timeout).must_equal '0'
      get_ivar(:@wait_time).must_equal '1'
      get_ivar(:@queues).must_equal []
    end
  end

  describe '#convert_queues' do
    it "logs if a queue string doesn't match anything" do
      mock = Minitest::Mock.new
      mock.expect :debug, nil, [String]
      mock.expect :warn, nil, ["No queue found for 'FooQueue'"]
      subject.stub :qurd_logger, mock do
        ret = subject.send :convert_queues, ['FooQueue']
        _(ret).must_be :empty?
      end
      mock.verify
    end

    it "logs if a queue regex doesn't match anything" do
      mock = Minitest::Mock.new
      mock.expect :debug, nil, [String]
      mock.expect :debug, nil, [String]
      mock.expect :debug, nil, [String]
      mock.expect :warn, nil, ["No queue found for '(?-mix:FooQueue)'"]
      subject.stub :qurd_logger, mock do
        ret = subject.send :convert_queues, ['/FooQueue/']
        _(ret).must_be :empty?
      end
      mock.verify
    end

    it 'converts names to urls' do
      ret = subject.send :convert_queues, [queue_name]
      _(ret).must_equal [queue_url]
    end

    it 'converts regexes to urls' do
      expected = %w(
        https://sqs.us-west-2.amazonaws.com/123456890/test2-ScalingNotificationsQueue-HPPYDAYSAGAI1
        https://us-west-2.queue.amazonaws.com/123456890/test3-ScalingNotificationsQueue-YYLG1O990SQI
        https://us-west-2.queue.amazonaws.com/123456890/test4-ScalingNotificationsQueue-1S1YEQQE2J7HI
        https://us-west-2.queue.amazonaws.com/123456890/test5-ScalingNotificationsQueue-55KK8HVCUXAL
        https://us-west-2.queue.amazonaws.com/123456890/test6-ScalingNotificationsQueue-HLG212XCGF9J
        https://us-west-2.queue.amazonaws.com/123456890/test7-ScalingNotificationsQueue-WBJFMQLXPJTE
        https://us-west-2.queue.amazonaws.com/123456890/test8-ScalingNotificationsQueue-1D4ZH9NTVP54Y
        https://us-west-2.queue.amazonaws.com/123456890/test9-ScalingNotificationsQueue-1XU3PAR1WTHCU
        https://us-west-2.queue.amazonaws.com/123456890/test10-ScalingNotificationsQueue-1UMGYCSIB1JH8
        https://us-west-2.queue.amazonaws.com/123456890/test11-ScalingNotificationsQueue-L0AKLNJ1XLBS
        https://us-west-2.queue.amazonaws.com/123456890/test12-ScalingNotificationsQueue-M09A379WLWFU
        https://us-west-2.queue.amazonaws.com/123456890/test13-ScalingNotificationsQueue-100VMU8AM3HT3
        https://us-west-2.queue.amazonaws.com/123456890/test14-ScalingNotificationsQueue-EL0IF9EJIIZ2
        https://us-west-2.queue.amazonaws.com/123456890/test15-ScalingNotificationsQueue-U701AIYCF4W4
        https://us-west-2.queue.amazonaws.com/123456890/test15-ScalingNotificationsQueue-1QFI52GEJIW
        https://us-west-2.queue.amazonaws.com/123456890/test16-ScalingNotificationsQueue-1SR2WCCTHI4O
        https://us-west-2.queue.amazonaws.com/123456890/test17-ScalingNotificationsQueue-BQSIQV79C3A1
        https://us-west-2.queue.amazonaws.com/123456890/test18-ScalingNotificationsQueue-1TDIPXAVBWD73
        https://us-west-2.queue.amazonaws.com/123456890/test19-ScalingNotificationsQueue-1U30UKNUS17YY
      )
      ret = subject.send :convert_queues, ['/ScalingNotificationsQueue/']
      _(ret).must_equal expected
      ret = subject.send :convert_queues, ['/scalingnotificationsqueue/i']
      _(ret).must_equal expected
      ret = subject.send :convert_queues, ["/
                                           scalingnotificationsqueue # comment
                                           /xi"]
      _(ret).must_equal expected
    end
  end
end
