# DEPRECATED - dogtrainer

**This gem is considered deprecated by its authors; we do not plan on releasing any future versions and no longer intend on supporting it.** Internally, we have mostly switched to using the [Datadog Terraform provider](https://www.terraform.io/docs/providers/datadog/index.html).

Build of master branch: [![CircleCI](https://circleci.com/gh/manheim/dogtrainer.svg?style=svg)](https://circleci.com/gh/manheim/dogtrainer)

Documentation: [http://www.rubydoc.info/gems/dogtrainer/](http://www.rubydoc.info/gems/dogtrainer/)

Wrapper around Datadog dogapi gem to simplify creation and management of Monitors and Boards.

This class provides methods to manage (upsert / ensure the existence and configuration of) Datadog
Monitors and TimeBoards/ScreenBoards.

## Installation

To use the helper class, add ``dogtrainer`` as a runtime dependency for your project.

Using the best-practice of declaring all of your dependencies in your ``gemspec``:

``Gemfile``:

```
source 'https://rubygems.org'
gemspec
```

And add in your ``.gemspec``:

```
gem.add_runtime_dependency 'dogtrainer'
```

## Usage

To use the Datadog helper, require the module and create an instance of the class,
passing it the required configuration information.

```ruby
require 'dogtrainer'

dog = DogTrainer::API.new(api_key, app_key, notify_to)
```

or

```ruby
require 'dogtrainer'

dog = DogTrainer::API.new(api_key, app_key, notify_to, 'string describing where to update monitors or boards')
```

* __api_key__ is your Datadog API Key, which you can find at https://app.datadoghq.com/account/settings#api
* __app_key__ is an application-specific key, which should be generated separately for every app or
  service that uses this class. These can be generated and seen at https://app.datadoghq.com/account/settings#api
* __notify_to__ is the string specifying Datadog monitor recipients in "@" form. If you are only managing Timeboards or
  Screenboards (not Monitors), this can be ``nil``.
* __repo_path__ is a string that will be included in all Monitor notification messages and TimeBoard/ScreenBoard descriptions,
  telling users where to find the code that created the Datadog resource. This is intended to alert users to code-managed
  items that shouldn't be manually changed. If this parameter is not specified, it will be obtained from the first usable
  and present value of: the ``GIT_URL`` environment variable, the ``CIRCLE_REPOSITORY_URL`` or the first remote URL found
  by running ``git config --local -l`` in the directory that contains the code calling this constructor.

### Usage Examples

These examples all rely on the ``require`` and class instantiation above.

#### Monitors

These configurations currently make some assumptions; if those aren't correct
for you, please open an issue. They also generate alert and escalation messages
from a template; see the example below to override them.

Event alert on sparse data (lack of data should not trigger an alert):

```ruby
# alert if more than 130 EC2 RunInstances API call Events in the last hour;
# do not alert if there is no data.
id = dog.upsert_monitor(
  "AWS Suspicious Activity - EC2 RunInstances in the past hour",
  "events('sources:cloudtrail priority:all tags:runinstances').rollup('count').last('1h') > 130",
  130,
  '<=',
  alert_no_data: false,
  mon_type: 'event alert'
)
puts "RunInstances monitor id: #{id}"
```

Metric alert, ignoring sparse data:

```ruby
# alert if aws.ec2.host_ok metric is > 2000 in the last hour, ignoring sparse data
id = dog.upsert_monitor(
  "AWS Suspicious Activity - Average Running (OK) EC2 Instances in the past hour",
  "avg(last_1h):sum:aws.ec2.host_ok{*} > 2000",
  2000,
  '<=',
  alert_no_data: false,
  mon_type: 'metric alert'
)
puts "aws.ec2.host_ok monitor id: #{id}"
```

Metric alert, also alerting on missing data:

```ruby
# alert if 'MY_ASG_NAME' ASG in service instances < 2; set no_data_timeframe
# to 60 minutes and evaluation_delay to 900 seconds, for sparse AWS metrics
dog.upsert_monitor(
  "ASG In-Service Instances",
  "avg(last_5m):sum:aws.autoscaling.group_in_service_instances{autoscaling_group:MY_ASG_NAME} < 2",
  2,
  '>=',
  no_data_timeframe: 60,
  evaluation_delay: 900
)
```

Service Check ("app.ok" on host my.host.name) alert, with separate warning (2),
critical (5) and OK (1) thresholds, evalulated over the last 6 checks:

```ruby
dog.upsert_monitor(
  "App Health on my.host.name",
  "\"app.ok\".over(\"host:my.host.name\").last(6).count_by_status()",
  { 'warning' => 2, 'critical' => 5, 'ok' => 1 },
  '<',
  alert_no_data: false,
  mon_type: 'service check'
)
```

Override alert and escalation messages with your own:

```ruby
dog.upsert_monitor(
  "ASG In-Service Instances",
  "avg(last_5m):sum:aws.autoscaling.group_in_service_instances{autoscaling_group:MY_ASG_NAME} < 2",
  2,
  '>=',
  message: 'my alert message',
  escalation_message: 'my escalation message'
)
```

Override only the alert message, leaving the default (generated by #generate_messages )
escalation message:

```ruby
dog.upsert_monitor(
  "ASG In-Service Instances",
  "avg(last_5m):sum:aws.autoscaling.group_in_service_instances{autoscaling_group:MY_ASG_NAME} < 2",
  2,
  '>=',
  message: 'my alert message'
)
```

Completely remove the escalation message, leaving the default
(generated by #generate_messages ) alert message:

```ruby
dog.upsert_monitor(
  "ASG In-Service Instances",
  "avg(last_5m):sum:aws.autoscaling.group_in_service_instances{autoscaling_group:MY_ASG_NAME} < 2",
  2,
  '>=',
  escalation_message: nil
)
```

##### Muting and Unmuting monitors

Mute a single monitor by ID number (12345):

```ruby
dog.mute_monitor_by_id(12345)
```

Mute a single monitor by ID number (12345) for one hour:

```ruby
ts = Time.now + 3600
dog.mute_monitor_by_id(12345, end_timestamp: ts.to_i)
```

Unmute a single monitor by ID number (12345):

```ruby
dog.unmute_monitor_by_id(12345)
```

Mute a single monitor by name for one hour:

```ruby
ts = Time.now + 3600
dog.mute_monitor_by_name('my whole monitor name', end_timestamp: ts.to_i)
```

Unmute a single monitor by name:

```ruby
dog.unmute_monitor_by_name('my whole monitor name')
```

Mute all monitors matching regex /ELB/ for one hour (this also accepts a String
  in addition to Regexp objects):

```ruby
ts = Time.now + 3600
dog.mute_monitors_by_regex(/ELB/, end_timestamp: ts.to_i)
```

Unmute all monitors matching /foo/ (provided as a String instead of Regexp):

```ruby
dog.unmute_monitors_by_regex('foo')
```

#### Boards

Create a TimeBoard with a handful of graphs about the "MY_ELB_NAME" ELB,
"MY_ASG_NAME" ASG and instances tagged with a Name of "MY_INSTANCE":

```ruby
asg_name = "MY_ASG_NAME"
elb_name = "MY_ELB_NAME"
instance_name = "MY_INSTANCE"

# generate graph definitions
graphs = [
  dog.graphdef(
    "ASG In-Service Instances",
    [
      "sum:aws.autoscaling.group_in_service_instances{autoscaling_group:#{asg_name}}",
      "sum:aws.autoscaling.group_desired_capacity{autoscaling_group:#{asg_name}}"
    ]
  ),
  dog.graphdef(
    "ELB Healthy Hosts Sum",
    "sum:aws.elb.healthy_host_count_deduped{host:#{elb_name}}",
    {'Desired' => 2}  # this is a Marker, a static line on the graph at y=2
  ),
  dog.graphdef(
    "ELB Latency",
    [
      "avg:aws.elb.latency{host:#{elb_name}}",
      "max:aws.elb.latency{host:#{elb_name}}"
    ]
  ),
  # Instance CPU Utilization from Datadog/EC2 integration
  dog.graphdef(
    "Instance EC2 CPU Utilization",
    "avg:aws.ec2.cpuutilization{name:#{instance_name}}"
  ),
  # Instance Free Memory from Datadog Agent on instance
  dog.graphdef(
    "Instance Free Memory",
    "avg:system.mem.free{name:#{instance_name}}"
  ),
]

# upsert the TimeBoard
dog.upsert_timeboard("My Account-Unique Board Name", graphs)
```

## Development

1. ``bundle install --path vendor``
2. ``bundle exec rake pre_commit`` to ensure spec tests are passing and style is valid before making your changes
3. make your changes, and write spec tests for them. You can run ``bundle exec guard`` to continually run spec tests and rubocop when files change.
4. ``bundle exec rake pre_commit`` to confirm your tests pass and your style is valid. You should confirm 100% coverage. If you wish, you can run ``bundle exec guard`` to dynamically run rspec, rubocop and YARD when relevant files change.
5. Update ``ChangeLog.md`` for your changes.
6. Run ``bundle exec rake yard:serve`` to generate documentation for your Gem and serve it live at [http://localhost:8808](http://localhost:8808), and ensure it looks correct.
7. Open a pull request for your changes.
8. When shipped, merge the PR. CircleCI will test.
9. Deployment is done locally, with ``bundle exec rake release``.

When running inside CircleCI, rspec will place reports and artifacts under the right locations for CircleCI to archive them. When running outside of CircleCI, coverage reports will be written to ``coverage/`` and test reports (HTML and JUnit XML) will be written to ``results/``.

## License

The gem is available as open source under the terms of the
[MIT License](http://opensource.org/licenses/MIT).
