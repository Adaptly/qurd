require 'test_helper'
describe Qurd::Mixins::Configuration do
  class TestConfigurationClass
    include Qurd::Mixins::Configuration
  end
  let(:subject) { TestConfigurationClass.new }

  describe '#qurd_config' do
    it 'gets the configuration instance' do
      subject.qurd_config.must_equal Qurd::Configuration.instance
    end
  end

  describe '#qurd_configuration' do
    it 'gets the configuration' do
      subject.qurd_config.init('test/inputs/qurd.yml')
      subject.qurd_configuration.must_be_kind_of Hashie::Mash
    end
  end

  describe '#qurd_logger' do
    it 'gets the cabin logger' do
      subject.qurd_config.init('test/inputs/qurd.yml')
      subject.qurd_logger.must_be_kind_of Cabin::Channel
    end
  end

  describe '#qurd_logger!' do
    it 'blows up' do
      subject.qurd_config.init('test/inputs/qurd.yml')
      lambda do
        subject.qurd_logger!('foo')
      end.must_raise RuntimeError
    end
  end
end
