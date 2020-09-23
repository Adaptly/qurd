# AWS sends status 400 for test/responses/aws/error-response.xml
module WebMockStubs
  def aws_sts_assume_role(file = 'test/responses/aws/sts-assume-role.xml',
                          status = 200)
    stub_request(:post, 'https://sts.amazonaws.com/')
      .with(body: /Action=AssumeRole/)
      .to_return(status: status.to_i, body: File.read(file))
  end

  def aws_ec2_describe_instances(file = 'test/responses/aws/ec2-describe-instances-0.xml',
                                 status = 200,
                                 region = 'us-west-2')
    stub_request(:post, "https://ec2.#{region}.amazonaws.com/")
      .with(body: /Action=DescribeInstances/)
      .to_return(status: status.to_i, body: File.read(file))
  end

  def aws_sqs_list_queues(file = 'test/responses/aws/sqs-list-queues-n.xml',
                          status = 200,
                          region = 'us-west-2')
    stub_request(:post, "https://sqs.#{region}.amazonaws.com/")
      .with(body: /Action=ListQueues/)
      .to_return(status: status.to_i, body: File.read(file))
  end

  def aws_sqs_set_queue_attributes(file = 'test/responses/aws/sqs-set-queue-attributes.xml',
                          status = 200,
                          region = 'us-west-2')
    stub_request(:post, %r{https://#{region}.queue.amazonaws.com/})
      .with(body: /Action=SetQueueAttributes/)
      .to_return(status: status.to_i, body: File.read(file))
    stub_request(:post, %r{https://sqs.#{region}.amazonaws.com/})
      .with(body: /Action=SetQueueAttributes/)
      .to_return(status: status.to_i, body: File.read(file))
  end

  def aws_sqs_receive_message(file = 'test/responses/aws/sqs-receive-message-1-other.xml',
                              queue_path = '/123456890/test2-ScalingNotificationsQueue-HPPYDAYSAGAI1',
                              status = 200,
                              region = 'us-west-2')
    stub_request(:post, "https://sqs.#{region}.amazonaws.com#{queue_path}")
      .with(body: /Action=ReceiveMessage/)
      .to_return(status: status.to_i, body: File.read(file))
  end

  def aws_route53_list_hosted_zones_by_name(file = 'test/responses/aws/route53-list-hosted-zones-by-name-1.xml',
                                            status = 200,
                                            region = 'us-west-2')
    stub_request(:get, %r{https://route53.amazonaws.com/2013-04-01/hostedzonesbyname})
      .to_return(status: status.to_i, body: File.read(file))
  end

  def aws_route53_list_resource_record_sets(file = 'test/responses/aws/route53-list-resource-record-sets-1.xml',
                                            status = 200,
                                            zone = 'Z3EWK6Z93GXEWJ',
                                            region = 'us-west-2')
    stub_request(:get, %r{https://route53.amazonaws.com/2013-04-01/hostedzone/#{zone}/rrset}i)
      .to_return(status: status.to_i, body: File.read(file))
  end

  def aws_route53_change_resource_record_sets(file = 'test/responses/aws/route53-change-resource-record-sets.xml',
                                              status = 200,
                                              zone = 'Z3EWK6Z93GXEWJ')
    stub_request(:post, "https://route53.amazonaws.com/2013-04-01/hostedzone/#{zone}/rrset/")
      .to_return(status: status.to_i, body: File.read(file))
  end

  def ec2metadata
    ec2_latest_meta_data_iam_security_credentials
    ec2_latest_meta_data_iam_security_credentials_client
    ec2_latest_api_token
  end

  def ec2_latest_api_token(file = 'test/responses/ec2/latest-api-token.txt',
                           status = 200)
    stub_request(:put, 'http://169.254.169.254/latest/api/token')
      .to_return(status: status.to_i, body: File.read(file))
  end

  def ec2_latest_meta_data_iam_security_credentials(file = 'test/responses/ec2/latest-meta-data-iam-security-credentials.txt',
                                                    status = 200)
    stub_request(:get, 'http://169.254.169.254/latest/meta-data/iam/security-credentials/')
      .to_return(status: status.to_i, body: File.read(file))
  end

  def ec2_latest_meta_data_iam_security_credentials_client(file = 'test/responses/ec2/latest-meta-data-iam-security-credentials-client.txt',
                                                           status = 200)
    stub_request(:get, 'http://169.254.169.254/latest/meta-data/iam/security-credentials/test-IAMRole-1X7IHUVCNNF5V')
      .to_return(status: status.to_i, body: File.read(file))
  end

  def chef_search(file = 'test/responses/chef/search-node-instance-1.json',
                       type = 'node',
                       search = 'instance_id:i-b57d975a',
                       status = 200)
    stub_request(:get, %r{https://api.opscode.com/organizations/foo/search/#{type}\?q=#{search}})
      .to_return(status: status,
                 body: File.read(file),
                 headers: {'Content-Type'=>'application/json'})
  end

  def chef_node_delete(node = 'test-414.staging.example.com', status = 200)
    stub_request(:delete, "https://api.opscode.com/organizations/foo/nodes/#{node}")
      .to_return(status: status, 
                 body: '',
                 headers: {'Content-Type'=>'application/json'})
  end

  def chef_client_delete(client = 'test-414.staging.example.com', status = 200)
    stub_request(:delete, "https://api.opscode.com/organizations/foo/clients/#{client}")
      .to_return(status: status, 
                 body: '',
                 headers: {'Content-Type'=>'application/json'})
  end

end
