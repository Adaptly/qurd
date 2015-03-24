require 'minitest'
require 'minitest/mock'
require 'minitest/autorun'
#require 'minitest/pride'
require 'webmock/minitest'
require 'support/web_mock_stubs'
require 'qurd'

WebMock.disable_net_connect!
Qurd::Configuration.instance.init('test/inputs/qurd.yml')
