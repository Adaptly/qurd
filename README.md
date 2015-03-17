# QURD - QUeue Resource Daemon

The Queue Resource Daemon is an extensible SQS monitoring service, which can be
configured to react to or ignore AutoScaling messages. Qurd can be configured to
monitor multiple accounts, any number of queues, and any type of auto scaling
event.

## Configuration

### accounts
### module_dir
### actions
### log_file
### log_level
### delete_ignored_messages

## Signals

### SIGHUP
### SIGUSR1
### SIGUSR2

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'qurd'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install qurd

## Usage

TODO: Write usage instructions here

## Contributing

1. Fork it ( https://github.com/Adaptly/qurd/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

