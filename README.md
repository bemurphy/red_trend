# RedTrend

Store your trend data in redis.

## Installation

Add this line to your application's Gemfile:

    gem 'red_trend'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install red_trend

## Usage

```ruby
require 'red_trend'

red_trend = RedTrend.new(:prefix => "project:9")
red_trend.record("post_views", 42)
red_trend.record("post_views", 53)
red_trend.record("post_views", 53)
red_trend.top("post_views") # => ["53", "42"]
```

## How it works

TODO

## Todos

Rip ActiveSupport entirely if possible; otherwise narrow the inclusion.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Create your specs and feature code
4. Commit your changes (`git commit -am 'Added some feature'`)
5. Push to the branch (`git push origin my-new-feature`)
6. Create new Pull Request
