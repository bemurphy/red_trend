require 'spec_helper'

describe RedTrend, "redis connection config at the class level" do
  let(:redis) { stub }

  it "can instantiate a default localhost redis instance" do
    RedTrend.redis = nil
    Redis.should_receive(:new).with().and_return(redis)
    RedTrend.redis.should == redis
  end

  it "can be overrided with a redis connection" do
    RedTrend.redis = redis
    RedTrend.redis.should == redis
  end
end

describe RedTrend, "defaults" do
  subject { RedTrend.new }

  it "cycles_count to 3" do
    subject.cycles_count.should == 3
  end

  it "cycle_unit to :hour" do
    subject.cycle_unit.should == :hour
  end

  it "cycle_length to 3 hours" do
    subject.cycle_interval.to_i.should == 3 * 60 * 60
  end
end

describe RedTrend, "overriding defaults" do
  subject { RedTrend.new(:cycles_count => 2, :cycle_unit => :minute) }

  it "allows setting the cycles_count" do
    subject.cycles_count.should == 2
  end

  it "allows setting the cycle_length" do
    subject.cycle_length.should == 60
  end

  it "accepts the cycle_length of :minute, :hour, or :day" do
    [:minute, :hour, :day].each do |unit|
      lambda {
        RedTrend.new(:cycle_length => unit)
      }.should_not raise_error
    end
  end

  it "raises an argument error for an unknown cycle length" do
    lambda {
      RedTrend.new(:cycle_unit => :foobar)
    }.should raise_error(ArgumentError)
  end
end

describe RedTrend, "cycle interval" do
  context "for a cycle_count of 2 and cycle_unit of :minute" do
    it "is 120" do
      subject = RedTrend.new(:cycles_count => 2, :cycle_unit => :minute)
      subject.cycle_interval.should == 120
    end
  end

  context "for a cycle_count of 4 and cycle_length of 1 day" do
    it "is 345600" do
      subject = RedTrend.new(:cycles_count => 4, :cycle_unit => :day)
      subject.cycle_interval.should == 345600
    end
  end
end

describe RedTrend, "getting the current cycle" do
  before do
    Timecop.freeze("2012-07-30 18:00:00 -0700")
  end

  context "for a default RedTrend" do
    subject { RedTrend.new }

    it "cycles from 1 through 3 on intervals based on the hour" do
      subject.current_cycle.should == 1
      Timecop.travel(3600)
      subject.current_cycle.should == 2
      Timecop.travel(3600)
      subject.current_cycle.should == 3
      Timecop.travel(3600)
      subject.current_cycle.should == 1
    end

    it "cycles from 2, 3, 1 on intervals based on the hour" do
      Timecop.freeze("2012-07-30 19:00:00 -0700")
      subject.current_cycle.should == 2
      Timecop.travel(3600)
      subject.current_cycle.should == 3
      Timecop.travel(3600)
      subject.current_cycle.should == 1
      Timecop.travel(3600)
      subject.current_cycle.should == 2
    end

    it "behaves when the time does not fall on the boundary" do
      subject.current_cycle.should == 1
      Timecop.travel(1800)
      subject.current_cycle.should == 1
      Timecop.travel(1800)
      subject.current_cycle.should == 2
    end
  end

  context "for a RedTrend of 4 cycles of 60 seconds" do
    subject { RedTrend.new(:cycles_count => 4, :cycle_unit => :minute) }

    it "cycles from 1 through 4 on intervals based on the minute" do
      subject.current_cycle.should == 1
      Timecop.travel(60)
      subject.current_cycle.should == 2
      Timecop.travel(60)
      subject.current_cycle.should == 3
      Timecop.travel(60)
      subject.current_cycle.should == 4
      Timecop.travel(60)
      subject.current_cycle.should == 1
    end
  end

  context "for a RedTrend of 2 cycles of 1 day" do
    subject { RedTrend.new(:cycles_count => 2, :cycle_unit => :day) }

    it "cycles from 1 through 2 on intervals based on the day" do
      subject.current_cycle.should == 1
      Timecop.travel(86400)
      subject.current_cycle.should == 2
      Timecop.travel(86400)
      subject.current_cycle.should == 1
    end
  end

  context "for a RedTrend of 3 cycles of 1 day starting with Dec 31" do
    subject { RedTrend.new(:cycles_count => 3, :cycle_unit => :day) }

    it "cycles from 1 through 2 on intervals based on the day" do
      Timecop.freeze("2012-12-31 18:00:00 -0700")
      subject.current_cycle.should == 1
      Timecop.travel(86400)
      subject.current_cycle.should == 2
      Timecop.travel(86400)
      subject.current_cycle.should == 3
      Timecop.travel(86400)
      subject.current_cycle.should == 1
    end
  end
end

describe RedTrend, "getting an array of cycle numbers" do
  subject { RedTrend.new :cycles_count => 4 }

  before do
    Timecop.freeze("2012-07-30 18:00:00 -0700")
  end

  it "starts with the current cycle to the last cycle and wraps back around" do
    subject.cycle_positions.should == [3, 2, 1, 4]
  end
end

describe RedTrend, "recording" do
  subject { RedTrend.new }
  let(:redis) { IntegrationTestRedis.client }

  before do
    Timecop.freeze("2012-07-30 18:00:00 -0700")
  end

  it "increments the score for the member at the current zset key" do
    subject.record("foobar", 42)
    redis.zscore("foobar:1", "42").should == 1
    subject.record("foobar", 42)
    redis.zscore("foobar:1", "42").should == 2
  end

  it "prefixes the key if the prefix option was set" do
    subject.options[:prefix] = "fizz:buzz"
    subject.record("foobar", 42)
    redis.zscore("fizz:buzz:foobar:1", "42").should == 1
  end

  it "sets the zset to expire when the cycle wraps back around to it" do
    subject.record("foobar", 42)
    redis.ttl("foobar:1").should == 10800

    Timecop.travel(1800)
    subject.record("foobar", 42)
    redis.ttl("foobar:1").should == 10800

    Timecop.travel(1800)
    subject.record("foobar", 42)
    redis.ttl("foobar:2").should == 10800
  end

  it "creates a union set from the current zsets" do
    redis.exists("foobar").should be_false
    subject.record("foobar", 42)
    redis.exists("foobar").should be_true
  end
end

describe RedTrend, "storing a union off all cycles" do
  subject { RedTrend.new }
  let(:redis) { IntegrationTestRedis.client }

  before do
    Timecop.freeze("2012-07-30 18:00:00 -0700")

    # Cycle 1
    subject.record("foobar", 1)
    Timecop.travel(1800)
    subject.record("foobar", 2)

    # Cycle 2
    Timecop.travel(1800)
    subject.record("foobar", 3)

    # Cycle 3
    Timecop.travel(3600)
    subject.record("foobar", 4)

    # Cycle 1
    Timecop.travel(3600)
    subject.record("foobar", 5)

    # Cycle 2
    Timecop.travel(3600)
    subject.record("foobar", 1)
  end

  it "unionizes the data from all the available cycles" do
    redis.zrange("foobar", 0, -1).should =~ %w[1 2 3 4 5]
  end

  it "weights the unionization to prefer newer data" do
    redis.zrevrangebyscore("foobar", '+inf', '-inf').should == %w[1 3 5 2 4]
  end

  it "builds a weight offset by dividing 1 by the cycles count and rounding to 1/10 precision" do
    subject.weight_offset.should == 0.3
    subject.options[:cycles_count] = 4
    subject.weight_offset.should == 0.2
  end

  it "uses the weight offset to build decreasing weights by subtracting multiples of the offset" do
    redis.zrevrangebyscore("foobar", '+inf', '-inf', :with_scores => true).map(&:last).should == [1.7, 1, 0.7, 0.7, 0.4]
  end
end

describe RedTrend, "getting the current top ids" do
  subject { RedTrend.new }

  before do
    1.upto(11) do |n|
      n.times { subject.record("foobar", n) }
    end
  end

  it "returns the top 10 zrevrange of the union set" do
    subject.top("foobar").should == %w[11 10 9 8 7 6 5 4 3 2]
  end

  it "can be given an optional limit" do
    subject.top("foobar", 3).should == %w[11 10 9]
  end
end
