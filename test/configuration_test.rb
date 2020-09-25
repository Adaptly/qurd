require 'test_helper'
describe Qurd::Configuration do
  include WebMockStubs

  subject {
    ec2metadata
    Qurd::Configuration.instance
  }
  let(:mock) { Minitest::Mock.new }
  let(:config) do
    {
      # dry_run:"true",
      # daemonize:false,
      pid_file: 'tmp/qurd.pid',
      # wait_time:"0",
      # visibility_timeout:"1",
      log_file: 'tmp/qurd.log',
      log_level: 'debug',
      aws_credentials: [
        {
          name: 'credentials',
          type: 'credentials',
          options: {
            access_key_id: 'access',
            secret_access_key: 'secret'
          }
        }
      ],
      auto_scaling_queues: {
        staging: {
          credentials: 'credentials',
          region: 'us-west-2',
          queues: ['/ScalingNotificationsQueue/']
        }
      },
      actions: {
        launch: ['Qurd::Action::Dummy'],
        launch_error: ['Qurd::Action::Dummy'],
        terminate: ['Qurd::Action::Dummy'],
        terminate_error: ['Qurd::Action::Dummy'],
        test: ['Qurd::Action::Dummy']
      }
    }
  end

  def hashie_config(merge = {})
    Hashie::Mash.new(config.merge!(merge))
  end

  def stub_yaml(config, &_block)
    YAML.stub :load, config do
      yield if block_given?
    end
  end

  describe '#init' do
    it 'sets default config values' do
      config.merge!(log_file: nil, pid_file: nil)
      stub_yaml config do
        subject.init('/dev/null')
        _(subject.config.daemonize).must_equal false
        _(subject.config.dry_run).must_equal false
        _(subject.config.listen_timeout).must_equal 300.0
        _(subject.config.pid_file).must_equal '/var/run/qurd/qurd.pid'
        _(subject.config.save_failures).must_equal true
        _(subject.config.sqs_set_attributes_timeout).must_equal 10.0
        _(subject.config.stats_interval).must_equal 600
        _(subject.config.visibility_timeout).must_equal '300'
        _(subject.config.wait_time).must_equal '20'
      end
    end

    it 'keeps config values' do
      config.merge!(
        daemonize: true,
        dry_run: true,
        listen_timeout: 2,
        pid_file: 'tmp/qurd.pid',
        save_failures: false,
        sqs_set_attributes_timeout: 3,
        stats_interval: 100,
        visibility_timeout: 0,
        wait_time: 1
      )
      stub_yaml config do
        subject.init('/dev/null')
        _(subject.config.daemonize).must_equal true
        _(subject.config.dry_run).must_equal true
        _(subject.config.listen_timeout).must_equal 2.0
        _(subject.config.pid_file).must_equal 'tmp/qurd.pid'
        _(subject.config.save_failures).must_equal false
        _(subject.config.sqs_set_attributes_timeout).must_equal 3.0
        _(subject.config.stats_interval).must_equal 100
        _(subject.config.visibility_timeout).must_equal '0'
        _(subject.config.wait_time).must_equal '1'
      end
    end
  end

  describe '#debug?' do
    it 'is true' do
      hashie = hashie_config(log_level: 'debug')
      subject.stub :config, hashie do
        _(subject.debug?).must_equal true
      end
    end

    it 'is false' do
      hashie = hashie_config(log_level: 'info')
      subject.stub :config, hashie do
        _(subject.debug?).must_equal false
      end
    end
  end

  describe '#logger!' do
    it 'logs and raises RuntimeError' do
      mock.expect :error, nil, ['foo']
      _(lambda do
        subject.stub :logger, mock do
          subject.logger!('foo')
        end
      end).must_raise RuntimeError, 'foo'
      mock.verify
    end

    it 'logs and raises StandardError' do
      mock.expect :error, nil, ['foo']
      _(lambda do
        subject.stub :logger, mock do
          subject.logger!('foo', StandardError)
        end
      end).must_raise StandardError, 'foo'
      mock.verify
    end
  end

  describe '#configure' do
    it 'configures logger, accounts, queues, and actions' do
      aws_sqs_list_queues
      aws_sqs_set_queue_attributes
      stub_yaml config do
        subject.configure('/dev/null')
      end
    end
  end

  describe '#configure_actions' do
    it 'raises when objects are not found' do
      config.merge!(actions: { launch: ['DoesNotExist'] })
      stub_yaml config do
        subject.init('/dev/null')
        _(lambda do
          subject.send :configure_actions
        end).must_raise RuntimeError, 'Class undefined for actions: DoesNotExist'
      end
    end

    it 'raises when action values are not arrays' do
      config.merge!(actions: { launch: 'Qurd::Action::Dummy' })
      stub_yaml config do
        subject.init('/dev/null')
        _(lambda do
          subject.send :configure_actions
        end).must_raise RuntimeError, 'Action types must be an array'
      end
    end
  end

  describe '#configure_listeners' do
    it 'creates accounts data structure' do
      aws_sqs_list_queues
      aws_sqs_set_queue_attributes
      stub_yaml config do
        subject.init '/dev/null'
        subject.send :configure_credentials
        subject.send :configure_auto_scaling_queues
        _(subject.config.listeners.count).must_equal 1
      end
    end
  end

  describe '#get_or_default' do
    class Dummy
      def nil
        nil
      end

      def true
        true
      end
    end
    let(:obj) { Dummy.new }

    it 'chooses a defined value' do
      val = subject.send :get_or_default, obj, :true, 0
      _(val).must_equal true
    end

    it 'chooses a default value' do
      val = subject.send :get_or_default, obj, :nil, 0
      _(val).must_equal 0
    end

    it 'casts a value' do
      val = subject.send :get_or_default, obj, :nil, 0, :to_s
      _(val).must_equal '0'
    end
  end

  describe '#verify_account!' do
    %w(credentials region queues).each do |key|
      let(:monitor) do
        {
          'credentials' =>  'foo',
          'region' =>  'bar',
          'queues'  => 'baz'
        }
      end

      it "raises if #{key} is nil" do
        monitor.delete(key)
        _(lambda do
          subject.send :verify_account!, :bam, monitor
        end).must_raise RuntimeError, "Account bam missing keys: #{key}"
      end

      it "raises if #{key} is empty" do
        monitor[key] = ''
        _(lambda do
          subject.send :verify_account!, :bam, monitor
        end).must_raise RuntimeError, "Account bam missing keys: #{key}"
      end

      it 'is ok' do
        ret = subject.send :verify_account!, :bam, monitor
        _(ret).must_equal nil
      end
    end
  end

  describe '#mkdir_p_file!' do
    it 'makes directories' do
      subject.send :mkdir_p_file!, '/tmp/qurd-test/foo/bar/bam/baz.txt'
      File.new('/tmp/qurd-test/foo/bar/bam')
      `rm -rf /tmp/qurd-test`
    end

    it 'raises RuntimeError' do
      skip "can't be root" if Process.uid == 0
      _(lambda do
        subject.send :mkdir_p_file!, '/etc/foo'
      end).must_raise RuntimeError, 'Directory not writable: /etc'
    end
  end

  describe '#default_credentials' do
    it 'creates a default' do
      ec2metadata
      ret = subject.send :default_credentials
      _(ret[0][0]).must_equal 'default'
      _(ret[0][1]).must_be_kind_of Aws::InstanceProfileCredentials
      _(ret.count).must_equal 1
    end
  end

  describe '#assume_role_credentials' do
    let(:cred) do
      Hashie::Mash.new(name: 'foo',
                       options: {
                         role_arn: 'arn:aws:iam::1:user/bob@example.com',
                         role_session_name: 'foo'
                       })
    end
    %w(policy duration_seconds external_id).each do |key|
      it "sets option #{key}" do
        Aws.config[:region] = 'us-west-2'
        aws_sts_assume_role
        cred.options[key] = '1'
        ret = subject.send :assume_role_credentials, cred
        _(ret[0]).must_equal cred.name
        _(ret[1]).must_be_kind_of Aws::AssumeRoleCredentials
        Aws.config[:region] = nil
      end
    end
  end

  describe '#credentials' do
    let(:cred) do
      Hashie::Mash.new(name: 'foo',
                       options: {
                         access_key_id: 'abc',
                         secret_access_key: 'def'
                       })
    end
    it 'sets access_key_id and secret_access_key' do
      ret = subject.send :credentials, cred
      _(ret[0]).must_equal cred.name
      _(ret[1].access_key_id).must_equal cred.options.access_key_id
      _(ret[1].secret_access_key).must_equal cred.options.secret_access_key
    end

    it 'sets access_key_id, secret_access_key, and session_token' do
      cred.options.session_token = 'foo'
      ret = subject.send :credentials, cred
      _(ret[0]).must_equal cred.name
      _(ret[1].access_key_id).must_equal cred.options.access_key_id
      _(ret[1].secret_access_key).must_equal cred.options.secret_access_key
      _(ret[1].session_token).must_equal cred.options.session_token
    end
  end

  describe '#instance_profile_credentials' do
    let(:cred) do
      Hashie::Mash.new(name: 'foo',
                       options: {
                         retries: 0,
                         http_open_timeout: 0,
                         http_read_timeout: 0
                       })
    end
    %w(port delay http_debug_output).each do |key|
      it "sets option #{key}" do
        ec2metadata
        cred.options[key] = '80'
        ret = subject.send :instance_profile_credentials, cred
        _(ret[0]).must_equal cred.name
        _(ret[1]).must_be_kind_of Aws::InstanceProfileCredentials
      end
    end
  end

  describe '#string2class' do
    it 'returns a class' do
      ret = subject.send :string2class, 'Qurd::Action::Dummy'
      _(ret).must_equal Qurd::Action::Dummy
    end
  end
end
