# dogtrainer

Build of master branch: [![CircleCI](https://circleci.com/gh/manheim/dogtrainer.svg?style=svg)](https://circleci.com/gh/manheim/dogtrainer)

Documentation: [http://www.rubydoc.info/gems/dogtrainer/](http://www.rubydoc.info/gems/dogtrainer/)

Wrapper around DataDog dogapi gem to simplify creation and management of Monitors and Boards.

This class provides methods to manage (upsert / ensure the existence and configuration of) DataDog
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

To use the DataDog helper, require the module and create an instance of the class,
passing it the required configuration information.

```ruby
require 'dogapi'
require 'manheim_helpers/datadog'

dog = ManheimHelpers::DataDog.new(api_key, app_key, notify_to)
```

* __api_key__ is your DataDog API Key, which you can find at https://app.datadoghq.com/account/settings#api
* __app_key__ is an application-specific key, which should be generated separately for every app or
  service that uses this class. These can be generated and seen at https://app.datadoghq.com/account/settings#api
* __notify_to__ is the string specifying DataDog monitor recipients in "@" form. If you are only managing Timeboards or
  Screenboards (not Monitors), this can be ``nil``.

### Usage Examples

These examples all rely on the ``require`` and class instantiation above.

#### Monitors

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
# alert if 'MY_ASG_NAME' ASG in service instances < 2
dog.upsert_monitor(
  "ASG In-Service Instances",
  "avg(last_5m):sum:aws.autoscaling.group_in_service_instances{autoscaling_group:MY_ASG_NAME} < 2",
  2,
  '>='
)
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
  # Instance CPU Utilization from DataDog/EC2 integration
  dog.graphdef(
    "Instance EC2 CPU Utilization",
    "avg:aws.ec2.cpuutilization{name:#{instance_name}}"
  ),
  # Instance Free Memory from DataDog Agent on instance
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
