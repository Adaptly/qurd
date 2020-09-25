require 'test_helper'
describe Qurd::Mixins::AwsClients do
  class TestAwsClientsClass
    include Qurd::Mixins::AwsClients
    def region
      'us-west-2'
    end

    def aws_credentials
      Aws::Credentials.new('abc', 'def')
    end
  end
  let(:subject) { TestAwsClientsClass.new }

  describe '#aws_clients' do
    it 'instantiates a client, using a string' do
      _(subject.aws_client('SQS')).must_be_kind_of Aws::SQS::Client
    end

    it 'instantiates a client, using a symbol' do
      _(subject.aws_client(:SQS)).must_be_kind_of Aws::SQS::Client
    end

    it 'memoizes a client' do
      _(subject.aws_client(:EC2)).must_equal subject.aws_client(:EC2)
    end
  end
end
