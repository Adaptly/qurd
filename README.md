# QURD - QUeue Resource Daemon

The Queue Resource Daemon is an extensible SQS monitoring service, which can be
configured to react to or ignore AutoScaling messages. Qurd can be configured to
monitor multiple accounts, any number of queues, and any type of auto scaling
event.

When the daemon starts up, it finds the queues it's meant to monitor and sets
the `visibility_timeout` and `waittimeseconds` for each queue. Qurd uses long
polling to monitor the queues, by default.

This daemon makes extensive use of threads, you should really consider running
this with Ruby version 2.0 or higher.

## Plugin architecture

It is possible to provide your own actions, aside from Chef, Route53, and Dummy.
Dummy is provided as a simple example, but, in a nutshell, inherit from
Qurd::Action and override the actions you respond to.

Your action class can configure itself, by overriding the class method
`configure`. Instances must override the action methods launch, launch_error,
terminate, terminate_error, and test. Action instances have two attributes,
`message` and `context`. Message is a `Qurd::Message` instance. Context is a
`Cabin::Context`, used for logging. Callbacks, to interact with the action
before and after the instance are executed, can be overridden.

The mixins for AwsClients and Configuration are also available at the class and
instance level.

```ruby
# This contrived example creates a file in s3 when an instance launches
# It can be triggered by adding the class name to the list of actions in the
# configuration file, ie
#       bucket: example-bucket
#       actions:
#         launch:
#           - "Foo"
class Foo < Qurd::Action
  def self.configure(_action)
    qurd_configuration.bucket || qurd_logger!("Missing bucket")
  end

  def run_before
    aws_retryable do
      aws_client(:S3).delete_object(
        bucket: qurd_configuration.bucket,
        key: message.instance_id
      )
    end
  end

  def launch
    aws_retryable do
      aws_client(:S3).put_object(
        bucket: qurd_configuration.bucket,
        key: message.instance_id,
        body: message.instance.private_ip_address
      )
    end
  end

  def run_after
    aws_retryable do
      o = aws_client(:S3).get_object(
        bucket: qurd_configuration.bucket,
        key: message.instance_id
      )
      qurd_logger.debug("Found #{o.body}")
    end
  end

end
```

## AWS IAM Policy

QURD requires, at a minimum, SQS privileges and EC2 privileges, ie

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "qurd_sqs",
      "Effect": "Allow",
      "Action": [
        "sqs:DeleteMessage",
        "sqs:ListQueues",
        "sqs:ReceiveMessage",
        "sqs:SetQueueAttributes"
      ],
      "Resource": [
        "*"
      ]
    },
    {
      "Sid": "qurd_ec2",
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeInstances"
      ],
      "Resource": [
        "*"
      ]
    }
  ]
}
```

If you are using the route53 action, you will also need

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "Stmt1428424119000",
            "Effect": "Allow",
            "Action": [
                "route53:ChangeResourceRecordSets",
                "route53:DeleteHostedZone",
                "route53:GetHostedZone",
                "route53:ListHostedZones",
                "route53:ListResourceRecordSets"
            ],
            "Resource": [
                "*"
            ]
        }
    ]
}
```

## Configuration

To configure the daemon, edit the YAML configuration file. The default path is
`/etc/qurd/config.yml`. An alternate path can be specified on the command line.

<table>
  <tr>
    <th>Option</th>
    <th>Description</th>
    <th>Type</th>
    <th>Default</th>
  </tr>

  <tr>
    <td><tt><a href="#aws_credentials">aws_credentials</a></tt></td>
    <td>AWS credentials</td>
    <td><tt>[Array&lt;Hash&gt;]</tt></td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td><tt><a href="#auto_scaling_queues">auto_scaling_queues</a></tt></td>
    <td>Describe the queues to be monitored</td>
    <td><tt>[Hash&lt;Hash&gt;]</tt></td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td><tt><a href="#actions">actions</a></tt></td>
    <td>describe actions to take, for any autoscaling event</td>
    <td><tt>[Hash&lt;Array&gt;]</tt></td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td><tt>daemonize</tt></td>
    <td>Force qurd to log to a file, even if <tt>log_file</tt> is not defined.</td>
    <td><tt>Boolean</tt></td>
    <td><tt>false</tt></td>
  </tr>

  <tr>
    <td><tt>dry_run</tt></td>
    <td>Log what qurd would have done</td>
    <td><tt>Boolean</tt></td>
    <td><tt>false</tt></td>
  </tr>

  <tr>
    <td><tt>listen_timeout</tt></td>
    <td>Defines the timeout, in seconds, for a thread to process a message</td>
    <td><tt>Float</tt></td>
    <td><tt>visibility_timeout</tt></td>
  </tr>

  <tr>
    <td><tt>log_file</tt></td>
    <td>The path to qurd's log file</td>
    <td><tt>String</tt></td>
    <td><tt>/var/log/qurd/qurd.log</tt></td>
  </tr>

  <tr>
    <td><tt>log_level</tt></td>
    <td>The log level to catch</td>
    <td><tt>String</tt></td>
    <td><tt>info</tt></td>
  </tr>

  <tr>
    <td><tt>pid_file</tt></td>
    <td>The path of qurd's pid file</td>
    <td><tt>String</tt></td>
    <td><tt>/var/run/qurd/qurd.pid</tt></td>
  </tr>

  <tr>
    <td><tt>save_failures</tt></td>
    <td>Save messages if any action fails</td>
    <td><tt>Boolean</tt></td>
    <td><tt>true</tt></td>
  </tr>

  <tr>
    <td><tt>sqs_set_attributes_timeout</tt></td>
    <td>Defines the timeout, in seconds, for a thread setting SQS attributes</td>
    <td><tt>Float</tt></td>
    <td><tt>10</tt></td>
  </tr>

  <tr>
    <td><tt>visibility_timeout</tt></td>
    <td>Set the SQS <a href="http://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/AboutVT.html">visibility timeout</a></td>
    <td><tt>Integer</tt></td>
    <td><tt>300</tt></td>
  </tr>

  <tr>
    <td><tt>wait_time</tt></td>
    <td>Set the SQS <a href="http://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-long-polling.html">wait time seconds</a></td>
    <td><tt>Integer</tt></td>
    <td><tt>20</tt></td>
  </tr>

</table>

### aws_credentials
<a name="aws_credentials">

Qurd supports [AssumeRoleCredentials][1], [Credentials][2],
[InstanceProfileCredentials][3], and [SharedCredentials][4]. Each credential
must be named and must have a type defined. The options key allows the caller to
define keys and values, mirroring the options for each of the credential types.

If no aws_credentials are defined in the configuration file, the key `default`
is created and it will attempt to use `Aws::InstanceProfileCredentials`. Each
auto_scaling_queues will have its credentials automatically set to `default`.

```yaml
aws_credentials:
  - name: prod
    type: assume_role_credentials
    options:
      role_arn: "arn:aws:iam::1:user/bob@example.com"
      role_session_name: foo
  - name: staging
    type: credentials
    options:
      access_key_id: abc123
      secret_access_key: 123abc
  - name: dev
    type: instance_profile_credentials
  - name: test
    type: shared_credentials
    options:
      profile_name: default
```

### auto_scaling_queues
<a name="auto_scaling_queues">

A hash of hashes, which describe the queues to be monitored. The outer key is
the name of the group of queues, ie production, staging, etc. The inner keys
`credentials`, `region`, and `queues` are required. Credentials should refer to the
`name` of an `aws_credential`. The `region` is the region of the queues. The
`queues` key is an array of queue names and regular expressions. Regular
expressions are strings, which begin and end with forward slash. Regular
expressions can also have [modifiers][5] applied to them.

The optional keys `wait_time` and `visibility_timeout` override the global
options of the same name. 

The `credentials` key will be overridden, and set to `default`, if no
`aws_credentials` are defined.

```yaml
auto_scaling_queues:
  dev:
    credentials: dev
    region: us-east-1
    queues: "/scalingnotificationsqueue/i"
  staging:
    credentials: staging
    region: us-west-2
    visibility_timeout: 100
    wait_time: 20
    queues:
      - FooQueue
      - BarQueue
      - "/ScalingNotificationsQueue/"
```

### actions
<a name="actions">

A hash of arrays, describing actions to take, for any autoscaling event. To test
the various options, you could configure the dummy action for each event.

```yaml
actions:
  launch:
    - "Qurd::Action::Dummy"
  launch_error:
    - "Qurd::Action::Dummy"
  terminate:
    - "Qurd::Action::Dummy"
  terminate_error:
    - "Qurd::Action::Dummy"
  test:
    - "Qurd::Action::Dummy"
```

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

`qurd [/PATH/TO/CONFIG.yml]`

## Tests

`bundle exec rake`

WebMock stubs can be found in test/support/web_mock_stubs.rb, responses are in
test/responses. 

## Contributing

1. Fork it ( https://github.com/Adaptly/qurd/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
1. Write some tests!
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

[1]: http://docs.aws.amazon.com/sdkforruby/api/Aws/AssumeRoleCredentials.html
[2]: http://docs.aws.amazon.com/sdkforruby/api/Aws/Credentials.html
[3]: http://docs.aws.amazon.com/sdkforruby/api/Aws/InstanceProfileCredentials.html
[4]: http://docs.aws.amazon.com/sdkforruby/api/Aws/SharedCredentials.html
[5]: http://ruby-doc.org/core-2.1.1/Regexp.html#class-Regexp-label-Options
