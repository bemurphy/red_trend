require 'rspec'
require 'timecop'

require File.expand_path("../../lib/red_trend", __FILE__)

require "integration_test_redis"
IntegrationTestRedis.start

RSpec.configure do |config|
  config.mock_with :rspec

  config.before(:each) do
    RedTrend.redis = IntegrationTestRedis.client
    IntegrationTestRedis.client.flushdb
  end
end
