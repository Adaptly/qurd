require 'test_helper'
describe Qurd::Action::Chef do
  include WebMockStubs
  def setup
    ec2metadata
    aws_sqs_list_queues
    aws_sqs_set_queue_attributes
    aws_ec2_describe_instances 'test/responses/aws/ec2-describe-instances-1.xml'
    aws_sqs_receive_message 'test/responses/aws/sqs-receive-message-1-launch.xml'
  end

  let(:sqs_client) { Aws::SQS::Client.new(region: 'us-west-2') }
  let(:queue_url) { 'https://sqs.us-west-2.amazonaws.com/123456890/test2-ScalingNotificationsQueue-HPPYDAYSAGAI1' }
  let(:sqs_message) { sqs_client.receive_message(queue_url: queue_url).messages.first }
  let(:qurd_message) { Qurd::Message::AutoScaling.new(message: sqs_message, region: 'us-west-2', aws_credentials: Aws::Credentials.new('a', 'b')) }
  let(:subject) { Qurd::Action::Chef.new(qurd_message) }

  describe '#configure' do
    it 'adds the Qurd::Message::AutoScaling accessors chef_node, chef_client' do
      Qurd::Configuration.instance.init('test/inputs/qurd_chef.yml')
      Qurd::Action::Chef.configure('launch')
      _(Qurd::Message::AutoScaling.instance_methods).must_include :chef_node
      _(Qurd::Message::AutoScaling.instance_methods).must_include :chef_client
    end

    it 'sets the logger for chef' do
      Qurd::Configuration.instance.init('test/inputs/qurd_chef.yml')
      Qurd::Action::Chef.configure('launch')
      _(::Chef::Config[:log_location].path).must_equal 'tmp/qurd.log'
    end

    it 'sets the chef log level' do
      expected = Qurd::Configuration.instance.config.log_level
      Qurd::Configuration.instance.init('test/inputs/qurd_chef.yml')
      Qurd::Action::Chef.configure('launch')
      _(::Chef::Config[:log_level]).must_equal expected
    end
  end

  describe '#chef_search' do
    it 'memoizes Chef::Search::Query' do
      _(subject.send(:chef_search)).must_equal subject.send(:chef_search)
    end
  end

  describe '#run_before' do
    def setup
      ec2metadata
      aws_sqs_list_queues
      aws_sqs_set_queue_attributes
      aws_ec2_describe_instances 'test/responses/aws/ec2-describe-instances-1.xml'
      aws_sqs_receive_message 'test/responses/aws/sqs-receive-message-1-terminate.xml'
    end

    it 'finds many nodes' do
      chef_search(
        'test/responses/chef/search-node-instance-n.json',
        'node',
        "instance_id:#{qurd_message.instance_id}"
      )
      chef_search(
        'test/responses/chef/search-node-instance-n.json',
        'node',
        "name:test-414.staging.example.com"
      )
      chef_search(
        'test/responses/chef/search-client-name-n.json',
        'client',
        'name:test-414.staging.example.com'
      )
      Qurd::Configuration.instance.configure('test/inputs/qurd_chef.yml')
      subject.run_before
      _(subject.message.chef_node).must_equal nil
      _(subject.message.context[:chef_name]).must_equal nil
    end

    it 'finds a node (instance_id) and client' do
      chef_search(
        'test/responses/chef/search-node-instance-1.json',
        'node',
        "instance_id:#{qurd_message.instance_id}"
      )
      chef_search(
        'test/responses/chef/search-client-name-1.json',
        'client',
        'name:test-414.staging.example.com'
      )
      Qurd::Configuration.instance.configure('test/inputs/qurd_chef.yml')
      subject.run_before
      _(subject.message.chef_node).must_be_kind_of Chef::Node
      _(subject.message.context[:chef_name]).must_equal 'test-414.staging.example.com'
      _(subject.message.chef_client).must_be_kind_of Chef::ApiClient
      _(subject.message.context[:chef_client_name]).must_equal 'test-414.staging.example.com'
    end

    it 'finds a node (name) and client' do
      chef_search(
        'test/responses/chef/search-node-instance-0.json',
        'node',
        "instance_id:#{qurd_message.instance_id}"
      )
      chef_search(
        'test/responses/chef/search-node-instance-1.json',
        'node',
        "name:test-414.staging.example.com"
      )
      chef_search(
        'test/responses/chef/search-client-name-1.json',
        'client',
        'name:test-414.staging.example.com'
      )
      Qurd::Configuration.instance.configure('test/inputs/qurd_chef.yml')
      subject.run_before
      _(subject.message.chef_node).must_be_kind_of Chef::Node
      _(subject.message.context[:chef_name]).must_equal 'test-414.staging.example.com'
      _(subject.message.chef_client).must_be_kind_of Chef::ApiClient
      _(subject.message.context[:chef_client_name]).must_equal 'test-414.staging.example.com'
    end

    it 'does not find a node' do
      chef_search(
        'test/responses/chef/search-node-instance-0.json',
        'node',
        "instance_id:#{qurd_message.instance_id}"
      )
      chef_search(
        'test/responses/chef/search-node-instance-0.json',
        'node',
        "name:test-414.staging.example.com"
      )
      chef_search(
        'test/responses/chef/search-client-name-0.json',
        'client',
        'name:test-414.staging.example.com'
      )
      Qurd::Configuration.instance.configure('test/inputs/qurd_chef.yml')
      subject.run_before
      _(subject.message.chef_node).must_equal nil
      _(subject.message.context[:chef_name]).must_equal nil
    end

  end

  describe '#terminate' do
    def setup
      ec2metadata
      aws_sqs_list_queues
      aws_sqs_set_queue_attributes
      aws_ec2_describe_instances 'test/responses/aws/ec2-describe-instances-1.xml'
      aws_sqs_receive_message 'test/responses/aws/sqs-receive-message-1-terminate.xml'
      chef_node_delete
      chef_client_delete
      chef_search(
        'test/responses/chef/search-node-instance-1.json',
        'node',
        "instance_id:#{qurd_message.instance_id}"
      )
      chef_search(
        'test/responses/chef/search-client-name-1.json',
        'client',
        'name:test-414.staging.example.com'
      )
    end
    let(:mock) { Minitest::Mock.new }
    let(:node_mock) { Minitest::Mock.new }
    let(:client_mock) { Minitest::Mock.new }

    it 'saves a node; dry_run' do
      mock.expect :debug, nil, ['Chef node found']
      mock.expect :debug, nil, ['Dry run; missing node']

      Qurd::Configuration.instance.configure('test/inputs/qurd_chef.yml')
      Qurd::Configuration.instance.config.dry_run = true
      subject.run_before
      subject.stub :qurd_logger, mock do
        subject.terminate
      end
      mock.verify
    end

    it 'destroys a node; not dry_run; not failed' do
      mock.expect :debug, nil, [String]
      node_mock.expect :destroy, nil
      node_mock.expect :nil?, false
      client_mock.expect :destroy, nil
      client_mock.expect :nil?, false

      Qurd::Configuration.instance.configure('test/inputs/qurd_chef.yml')
      Qurd::Configuration.instance.config.dry_run = false
      subject.run_before
      qurd_message.stub :chef_client, client_mock do
        qurd_message.stub :chef_node, node_mock do
          subject.stub :qurd_logger, mock do
            subject.terminate
          end
        end
      end
      mock.verify
      node_mock.verify
      client_mock.verify
    end

    it 'keeps a node; failed' do
      mock.expect :warn, nil, ['Not deleting, message failed to process']
      Qurd::Configuration.instance.configure('test/inputs/qurd_chef.yml')
      Qurd::Configuration.instance.config.dry_run = false
      subject.run_before
      qurd_message.stub :failed?, true do
        subject.stub :qurd_logger, mock do
          subject.terminate
        end
      end
      mock.verify
    end

  end

  describe '#test' do
    def setup
      ec2metadata
      aws_sqs_list_queues
      aws_sqs_set_queue_attributes
      aws_ec2_describe_instances 'test/responses/aws/ec2-describe-instances-1.xml'
      aws_sqs_receive_message 'test/responses/aws/sqs-receive-message-1-test.xml'
      chef_search(
        'test/responses/chef/search-node-instance-1.json',
        'node',
        "instance_id:#{qurd_message.instance_id}"
      )
      chef_search(
        'test/responses/chef/search-client-name-1.json',
        'client',
        'name:test-414.staging.example.com'
      )
    end
    let(:mock) { Minitest::Mock.new }

    it 'logs Test' do
      mock.expect :info, nil, ['Test']
      Qurd::Configuration.instance.configure('test/inputs/qurd_chef.yml')
      subject.run_before
      subject.stub :qurd_logger, mock do
        subject.test
      end
      mock.verify
    end
  end
end
