require 'test_helper'
describe Qurd::Action::Route53 do
  include WebMockStubs

  let(:sqs_client) { Aws::SQS::Client.new(region: 'us-west-2') }
  let(:queue_url) { 'https://sqs.us-west-2.amazonaws.com/123456890/test2-ScalingNotificationsQueue-HPPYDAYSAGAI1' }
  let(:sqs_message) { sqs_client.receive_message(queue_url: queue_url).messages.first }
  let(:qurd_message) { Qurd::Message.new(message: sqs_message, region: 'us-west-2', aws_credentials: Aws::Credentials.new('a', 'b'), name: 'staging') }
  let(:subject) { Qurd::Action::Route53.new(qurd_message) }
  let(:subject_private) { Qurd::Action::Route53Private.new(qurd_message) }

  describe '#terminate' do
    def setup
      aws_sqs_list_queues
      aws_sqs_set_queue_attributes
      aws_ec2_describe_instances 
      aws_ec2_describe_instances 'test/responses/aws/ec2-describe-instances-1-private.xml'
      aws_sqs_receive_message 
      aws_sqs_receive_message 'test/responses/aws/sqs-receive-message-1-terminate-private.xml'
      aws_route53_list_hosted_zones_by_name
      aws_route53_list_hosted_zones_by_name'test/responses/aws/route53-list-hosted-zones-by-name-1-private.xml'
      aws_route53_list_resource_record_sets
      aws_route53_list_resource_record_sets'test/responses/aws/route53-list-resource-record-sets-1-private.xml', 200, 'Z3EWK6Z93GXEWX'
      Qurd::Configuration.instance.configure('test/inputs/qurd_route53_both.yml')
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
        subject_private.terminate
      end
      mock.verify
    end

    it 'destroys a node; not dry_run; not failed' do
      aws_route53_change_resource_record_sets
      aws_route53_change_resource_record_sets'test/responses/aws/route53-change-resource-record-sets.xml', 200, 'Z3EWK6Z93GXEWX' 
      Qurd::Configuration.instance.config.dry_run = false
      subject.terminate
      subject_private.terminate
    end

    it 'raises during destroys a node; not dry_run; not failed' do
      aws_route53_change_resource_record_sets('test/responses/aws/route53-change-resource-record-sets.xml', 500)
      aws_route53_change_resource_record_sets('test/responses/aws/route53-change-resource-record-sets.xml', 500, 'Z3EWK6Z93GXEWX')
      Qurd::Configuration.instance.config.dry_run = false
      lambda {
        subject.terminate
        subject_private.terminate
      }.must_raise Aws::Route53::Errors::Http500Error
    end

    it 'keeps a node; failed' do
      mock.expect :warn, nil, ['Not deleting, message failed to process']
      qurd_message.stub :failed?, true do
        subject.stub :qurd_logger, mock do
          Qurd::Configuration.instance.config.dry_run = false
          subject.terminate
          subject_private.terminate
        end
      end
      mock.verify
    end

    it 'calls message.failed!' do
      aws_route53_change_resource_record_sets('test/responses/aws/route53-change-resource-record-sets.xml')
      aws_route53_change_resource_record_sets('test/responses/aws/route53-change-resource-record-sets.xml', 200, 'Z3EWK6Z93GXEWX')
      aws_route53_list_resource_record_sets('test/responses/aws/route53-list-resource-record-sets-0.xml')
      aws_route53_list_resource_record_sets('test/responses/aws/route53-list-resource-record-sets-0.xml', 200, 'Z3EWK6Z93GXEWX')
      Qurd::Configuration.instance.config.dry_run = false
      subject.terminate
      subject_private.terminate
      qurd_message.failed?.must_equal true
    end

  end

end
