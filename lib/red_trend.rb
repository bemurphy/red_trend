require 'redis'
require "red_trend/version"
require 'tzinfo'

class RedTrend
  CYCLE_UNITS = {
    :minute => 60,
    :hour  => 3600,
    :day => 86400
  }.freeze

  class << self
    attr_writer :redis

    def redis
      @redis ||= Redis.new
    end
  end

  attr_reader :options

  def initialize(options = {})
    @options = options
    unless CYCLE_UNITS.include?(cycle_unit)
      raise ArgumentError, "cycle unit must be in #{CYCLE_UNITS.keys}"
    end
  end

  # How many cycles we'll persist data for
  def cycles_count
    @options.fetch(:cycles_count, 3)
  end

  def cycle_length
    CYCLE_UNITS[cycle_unit]
  end

  # The length of 1 cycle
  def cycle_unit
    @options.fetch(:cycle_unit, :hour)
  end

  # The interval length of each cycle, probably
  # days for production
  def cycle_interval
    cycle_length * cycles_count
  end

  def current_cycle
    method = case cycle_unit
             when :minute then :min
             when :hour then :hour
             when :day then :yday
             end

    time = @time || Time.now
    (time.send(method) % cycles_count) + 1
  end

  def cycle_positions
    1.upto(cycles_count - 1).inject([current_cycle]) do |n_cycles, offset|
      n = current_cycle - offset
      n = n + cycles_count if n < 1
      n_cycles << n
    end
  end

  # Increment the leaderboard score for the object on
  # the sorted set for the current cycle.  Make the key
  # volitile so that it doesn't persist past the number
  # of cycles.  Store the union score set after each
  # new score
  def record(key, member)
    @time = Time.now

    n_key = make_key(key, current_cycle)

    zcard = redis.zcard(n_key)

    redis.multi do
      redis.zincrby n_key, 1, member
      # FIXME I'm not certain the second redis.ttl is working in the multi
      if zcard < 1 || redis.ttl(n_key) == -1
        redis.expire n_key, calculate_expire_seconds
      end
      unionize_sets(key)
    end

    @time = nil

    true
  end

  # Returns top scoring ids for the current interval
  def top(key, limit = 10)
    redis.zrevrange make_key(key), 0, limit - 1
  end

  def weight_offset
    ("%0.1f" % (1 / cycles_count.to_f)).to_f
  end

  def cycle_weights
    cycles_count.times.inject([]) do |weights, n|
      weights << 1 - n * weight_offset
    end
  end

  private

  def make_key(*args)
    key_parts = [options[:prefix]]
    key_parts.concat Array(args)
    key_parts.compact.join(":")
  end

  def redis
    self.class.redis
  end

  # The time in seconds which the current cycle key should expire in
  def calculate_expire_seconds
    ((@time.to_f / cycle_length).floor * cycle_length + cycle_interval) - @time.to_i
  end

  # Take the scores from all current cycle sets and store
  # them as a union
  def unionize_sets(key)
    keys = cycle_positions.collect { |n| make_key(key, n) }
    redis.zunionstore(make_key(key), keys, :weights => cycle_weights)
  end
end
