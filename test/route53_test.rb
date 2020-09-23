require 'test_helper'
describe Qurd::Action::Route53 do
  include WebMockStubs

  let(:sqs_client) { Aws::SQS::Client.new(region: 'us-west-2') }
  let(:queue_url) { 'https://sqs.us-west-2.amazonaws.com/123456890/test2-ScalingNotificationsQueue-HPPYDAYSAGAI1' }
  let(:sqs_message) { sqs_client.receive_message(queue_url: queue_url).messages.first }
  let(:qurd_message) { Qurd::Message.new(message: sqs_message, region: 'us-west-2', aws_credentials: Aws::Credentials.new('a', 'b'), name: 'staging') }
  let(:subject) { Qurd::Action::Route53.new(qurd_message) }

  describe '#configure' do
    def setup
      aws_sqs_list_queues
      aws_sqs_set_queue_attributes
      aws_ec2_describe_instances 'test/responses/aws/ec2-describe-instances-1.xml'
      aws_sqs_receive_message 'test/responses/aws/sqs-receive-message-1-terminate.xml'
    end

    it 'verifies configuration' do
      Qurd::Configuration.instance.init('test/inputs/qurd_route53.yml')
      Qurd::Action::Route53.configure('launch')
      ret = Qurd::Action::Route53.instance_variable_get :@configure_done
      _(ret).must_equal true
    end

  end

  describe '#check_configuration' do
    it 'fails to configure' do
      Qurd::Configuration.instance.init('test/inputs/qurd_route53_wrong.yml')
      _(lambda {
        Qurd::Action::Route53.check_configuration
      }).must_raise RuntimeError, 'Missing configuration for route53: staging'
    end
  end

  describe '#instance_name' do
    def setup
      aws_sqs_list_queues
      aws_sqs_set_queue_attributes
      aws_sqs_receive_message 'test/responses/aws/sqs-receive-message-1-terminate.xml'
      Qurd::Configuration.instance.configure('test/inputs/qurd_route53.yml')
    end

    it 'returns a hostname' do
      aws_ec2_describe_instances 'test/responses/aws/ec2-describe-instances-1.xml'
      _(subject.send(:instance_name)).must_equal 'test-414.staging.example.com'
    end

    it 'returns nil' do
      aws_ec2_describe_instances 'test/responses/aws/ec2-describe-instances-0.xml'
      _(subject.send(:instance_name)).must_equal nil
    end
  end

  describe '#hosted_zone' do
    def setup
      aws_sqs_list_queues
      aws_sqs_set_queue_attributes
      aws_sqs_receive_message 'test/responses/aws/sqs-receive-message-1-terminate.xml'
      Qurd::Configuration.instance.configure('test/inputs/qurd_chef_route53.yml')
    end

    it 'finds a zone id' do
      aws_route53_list_hosted_zones_by_name
      ret = subject.send :hosted_zone
      _(ret.id).must_equal '/hostedzone/Z3EWK6Z93GXEWJ'
    end

    it 'raises Aws::Route53::Errors' do
      aws_route53_list_hosted_zones_by_name(
        'test/responses/aws/route53-list-hosted-zones-by-name-0.xml',
        500
      )
      _(lambda {
        subject.send :hosted_zone, 0
      }).must_raise Aws::Route53::Errors::Http500Error
    end
  end

  describe '#hostname' do
    def setup
      aws_sqs_list_queues
      aws_sqs_set_queue_attributes
      Qurd::Configuration.instance.configure('test/inputs/qurd_chef_route53.yml')
    end

    it 'uses the given hostname' do
      aws_ec2_describe_instances 'test/responses/aws/ec2-describe-instances-1.xml'
      aws_sqs_receive_message 'test/responses/aws/sqs-receive-message-1-terminate.xml' 
      ret = subject.send :hostname
      _(ret).must_equal 'test-414.staging.example.com.'
    end

    it 'sets the correct hostname' do
      aws_ec2_describe_instances 'test/responses/aws/ec2-describe-instances-1-private.xml'
      aws_sqs_receive_message 'test/responses/aws/sqs-receive-message-1-terminate-private.xml'
      ret = subject.send :hostname
      _(ret).must_equal 'test-414.staging.example.com.'
    end
  end

  describe '#resource_record' do
    def setup
      aws_sqs_list_queues
      aws_sqs_set_queue_attributes
      aws_ec2_describe_instances 'test/responses/aws/ec2-describe-instances-1.xml'
      aws_sqs_receive_message 'test/responses/aws/sqs-receive-message-1-terminate.xml'
      Qurd::Configuration.instance.configure('test/inputs/qurd_chef_route53.yml')
    end

    it 'finds a resource record' do
      aws_route53_list_hosted_zones_by_name
      aws_route53_list_resource_record_sets
      ret = subject.send :resource_record
      _(ret.name).must_equal 'test-414.staging.example.com.'
    end

    it 'raises Qurd::Action::Route53::Errors::ResourceNotFound' do
      aws_route53_list_hosted_zones_by_name
      aws_route53_list_resource_record_sets 'test/responses/aws/route53-list-resource-record-sets-0.xml'
      _(lambda {
        subject.send :resource_record, 0
      }).must_raise Qurd::Action::Route53::Errors::ResourceNotFound
    end

    it 'raises Aws::Route53::Errors' do
      aws_route53_list_hosted_zones_by_name
      aws_route53_list_resource_record_sets 'test/responses/aws/route53-list-resource-record-sets-0.xml', 500
      _(lambda {
        subject.send :resource_record, 0
      }).must_raise Aws::Route53::Errors::Http500Error
    end

  end

  describe '#chef_node_name' do
    def setup
      aws_sqs_list_queues
      aws_sqs_set_queue_attributes
      aws_sqs_receive_message 'test/responses/aws/sqs-receive-message-1-terminate.xml'
      Qurd::Configuration.instance.configure('test/inputs/qurd_chef_route53.yml')
    end

    it 'returns a hostname' do
      chef_search
      chef_search(
        'test/responses/chef/search-client-name-1.json',
        'client',
        'name:test-414.staging.example.com'
      )
      aws_ec2_describe_instances 'test/responses/aws/ec2-describe-instances-1.xml'
      chef = Qurd::Action::Chef.new(qurd_message)
      chef.run_before
      _(subject.send(:chef_node_name)).must_equal 'test-414.staging.example.com'
    end

    it 'returns nil' do
      chef_search 'test/responses/chef/search-node-instance-0.json'
      chef_search(
        'test/responses/chef/search-client-name-0.json',
        'client',
        'name:test-414.staging.example.com'
      )
      chef = Qurd::Action::Chef.new(qurd_message)
      aws_ec2_describe_instances 'test/responses/aws/ec2-describe-instances-0.xml'
      _(subject.send(:chef_node_name)).must_equal nil
    end
  end

  describe '#terminate' do
    def setup
      aws_sqs_list_queues
      aws_sqs_set_queue_attributes
      aws_ec2_describe_instances 'test/responses/aws/ec2-describe-instances-1.xml'
      aws_sqs_receive_message 'test/responses/aws/sqs-receive-message-1-terminate.xml'
      aws_route53_list_hosted_zones_by_name
      aws_route53_list_resource_record_sets
      Qurd::Configuration.instance.configure('test/inputs/qurd_chef_route53.yml')
    end
    let(:mock) { Minitest::Mock.new }

    it 'saves a node; dry_run' do
      mock.expect :debug, nil, [String]
      mock.expect :debug, nil, [String]
      mock.expect :debug, nil, [String]
      mock.expect :debug, nil, [String]
      mock.expect :debug, nil, [String]
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

    it 'raises during destroys a node; not dry_run; not failed' do
      aws_route53_change_resource_record_sets('test/responses/aws/route53-change-resource-record-sets.xml', 500)
      Qurd::Configuration.instance.config.dry_run = false
      _(lambda {
        subject.terminate
      }).must_raise Aws::Route53::Errors::Http500Error
    end

    it 'keeps a node; failed' do
      mock.expect :warn, nil, ['Not deleting, message failed to process']
      qurd_message.stub :failed?, true do
        subject.stub :qurd_logger, mock do
          Qurd::Configuration.instance.config.dry_run = false
          subject.terminate
        end
      end
      mock.verify
    end

    it 'calls message.failed!' do
      aws_route53_change_resource_record_sets('test/responses/aws/route53-change-resource-record-sets.xml')
      aws_route53_list_resource_record_sets('test/responses/aws/route53-list-resource-record-sets-0.xml')
      Qurd::Configuration.instance.config.dry_run = false
      subject.terminate
      qurd_message.failed?.must_equal true
    end

  end

  describe '#test' do
    def setup
      aws_sqs_list_queues
      aws_sqs_set_queue_attributes
      aws_ec2_describe_instances 'test/responses/aws/ec2-describe-instances-1.xml'
      aws_sqs_receive_message 'test/responses/aws/sqs-receive-message-1-terminate.xml'
      aws_route53_list_hosted_zones_by_name
      aws_route53_list_resource_record_sets
      Qurd::Configuration.instance.configure('test/inputs/qurd_chef_route53.yml')
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
