require 'git'
require 'dogapi'
require 'dogtrainer'

describe DogTrainer::API do
  subject do
    allow(Dogapi::Client).to receive(:new).and_return(nil)
    DogTrainer::API.new(
      'my_apikey', 'my_appkey', '@my-notify-to', 'my_repo_path'
    )
  end
  describe '#initialize' do
    it 'sets state variables to nil' do
      expect(subject.instance_variable_get('@monitors')).to be_nil
      expect(subject.instance_variable_get('@timeboards')).to be_nil
      expect(subject.instance_variable_get('@screenboards')).to be_nil
    end
    it 'includes DogTrainer::Logging' do
      expect(subject).to respond_to(:logger)
      expect(subject).to respond_to(:logger_name)
    end
    it 'sets an instance variables for notify_to parameter' do
      expect(subject.instance_variable_get('@notify_to')).to eq('@my-notify-to')
    end
    it 'instantiates Dogapi::Client' do
      x = DogTrainer::API.new(
        'my_apikey', 'my_appkey', '@my-notify-to', 'my/path'
      )
      expect(x.instance_variable_get('@dog')).to be_a(Dogapi::Client)
      expect(
        x.instance_variable_get('@dog')
          .instance_variable_get('@application_key')
      ).to eq('my_appkey')
      expect(
        x.instance_variable_get('@dog')
          .instance_variable_get('@api_key')
      ).to eq('my_apikey')
    end
    it 'uses repo_path parameter as @repo_path if specified' do
      allow_any_instance_of(DogTrainer::API).to receive(:get_repo_path)
        .and_return('foo/bar')

      expect_any_instance_of(DogTrainer::API).to_not receive(:get_repo_path)

      x = DogTrainer::API.new(
        'my_apikey', 'my_appkey', '@my-notify-to', 'my/path'
      )
      expect(x.instance_variable_get('@repo_path')).to eq('my/path')
    end
    it 'uses #get_repo_path if repo_path parameter not specified' do
      allow_any_instance_of(DogTrainer::API).to receive(:get_repo_path)
        .and_return('foo/bar')

      expect_any_instance_of(DogTrainer::API).to receive(:get_repo_path)
        .and_return('foo/bar')

      x = DogTrainer::API.new(
        'my_apikey', 'my_appkey', '@my-notify-to'
      )
      expect(x.instance_variable_get('@repo_path')).to eq('foo/bar')
    end
  end
  describe '#get_repo_path' do
    it 'calls #get_git_url_for_directory if ENV vars are not set' do
      allow(ENV).to receive(:has_key?).with('GIT_URL').and_return(false)
      allow(ENV).to receive(:has_key?).with('CIRCLE_REPOSITORY_URL')
        .and_return(false)
      allow(subject).to receive(:caller)
        .and_return(['foo', 'my/path/Rakefile:123'])
      allow(subject).to receive(:get_git_url_for_directory).with(any_args)
        .and_return('my/repo/path')

      expect(subject).to receive(:get_git_url_for_directory).with('my/path')
        .once
      expect(subject.get_repo_path).to eq('my/repo/path')
    end
    it 'raises an Exception if #get_git_url_for_directory returns nil' do
      allow(ENV).to receive(:has_key?).with('GIT_URL').and_return(false)
      allow(ENV).to receive(:has_key?).with('CIRCLE_REPOSITORY_URL')
        .and_return(false)
      allow(subject).to receive(:caller)
        .and_return(['foo', 'my/path/Rakefile:123'])
      allow(subject).to receive(:get_git_url_for_directory).with(any_args)
        .and_return(nil)

      expect(subject).to receive(:get_git_url_for_directory)
        .with('my/path').once
      expect { subject.get_repo_path }.to raise_error(
        RuntimeError,
        /Unable to determine source code path; please specify repo_path/
      )
    end
    it 'returns GIT_URL if set' do
      allow(ENV).to receive(:has_key?).with('GIT_URL').and_return(true)
      allow(ENV).to receive(:has_key?).with('CIRCLE_REPOSITORY_URL')
        .and_return(true)

      allow(ENV).to receive(:[]).with('GIT_URL').and_return('my/git/url')
      allow(ENV).to receive(:[]).with('CIRCLE_REPOSITORY_URL')
        .and_return('my/circle/url')
      allow(subject).to receive(:caller)
      allow(subject).to receive(:get_git_url_for_directory)

      expect(subject).to_not receive(:caller)
      expect(subject).to_not receive(:get_git_url_for_directory)
      expect(subject.get_repo_path).to eq('my/git/url')
    end
  end
  describe '#get_git_url_for_directory' do
    it 'returns nil if the command fails' do
      allow(Dir).to receive(:chdir).with(any_args) { |&block| block.call }
      expect(Dir).to receive(:chdir).once.with('/foo/bar')
      allow(subject).to receive(:`).with(any_args).and_raise(Errno::ENOENT)
      expect(subject).to receive(:`).once.with('git config --local -l')
      expect(subject.get_git_url_for_directory('/foo/bar')).to be_nil
    end
    it 'returns nil if no matching remotes' do
      allow(Dir).to receive(:chdir).with(any_args) { |&block| block.call }
      expect(Dir).to receive(:chdir).once.with('/foo/bar')
      allow(subject).to receive(:`).with(any_args).and_return('foobar')
      expect(subject).to receive(:`).once.with('git config --local -l')
      expect(subject.get_git_url_for_directory('/foo/bar')).to be_nil
    end
    it 'returns the first matching remote' do
      expected = 'git@github.com:jantman/puppet.git'
      output = [
        'core.repositoryformatversion=0',
        'core.filemode=true',
        'core.bare=false',
        'core.logallrefupdates=true',
        'remote.origin.url=git@github.com:jantman/puppet.git',
        'remote.origin.fetch=+refs/heads/*:refs/remotes/origin/*',
        'remote.origin.fetch=+refs/pull/*/head:refs/pull/origin/*',
        'branch.master.remote=origin',
        'branch.master.merge=refs/heads/master',
        'credential.helper=store --file=.git/credentials',
        'branch.gh-pages.remote=origin',
        'branch.gh-pages.merge=refs/heads/gh-pages',
        'remote.upstream.url=git@github.com:puppetlabs/puppet.git',
        'remote.upstream.fetch=+refs/heads/*:refs/remotes/upstream/*',
        'remote.upstream.fetch=+refs/pull/*/head:refs/pull/upstream/*'
      ].join("\n") + "\n"
      allow(Dir).to receive(:chdir).with(any_args) { |&block| block.call }
      expect(Dir).to receive(:chdir).once.with('/foo/bar')
      allow(subject).to receive(:`).with(any_args).and_return(output)
      expect(subject).to receive(:`).once.with('git config --local -l')
      expect(subject.get_git_url_for_directory('/foo/bar')).to eq(expected)
    end
  end
  describe '#generate_messages' do
    it 'returns the appropriate message' do
      expected = "{{#is_alert}}'mydesc' should be comp {{threshold}},"
      expected += " but is {{value}}.{{/is_alert}}\n"
      expected += "{{#is_recovery}}'mydesc' recovered  (current value "
      expected += '{{value}} is comp threshold of {{threshold}}).'
      expected += "{{/is_recovery}}\n(monitor and threshold configuration "
      expected += 'for this alert is managed by my_repo_path) @my-notify-to'
      msg, = subject.generate_messages('mydesc', 'comp')
      expect(msg).to eq(expected)
    end
    it 'returns the appropriate message' do
      escalation = "'mydesc' is still in error state (current value {{value}}"
      escalation += ' is comp threshold of {{threshold}})'
      _, esc = subject.generate_messages('mydesc', 'comp')
      expect(esc).to eq(escalation)
    end
  end
  describe '#params_for_monitor' do
    it 'returns the correct hash with default params' do
      expected = {
        'name' => 'monname',
        'type' => 'metric alert',
        'query' => 'my_query',
        'message' => 'my_msg',
        'tags' => [],
        'options' => {
          'notify_audit' => false,
          'locked' => false,
          'timeout_h' => 0,
          'silenced' => {},
          'thresholds' => { 'critical' => 123.4 },
          'require_full_window' => false,
          'notify_no_data' => true,
          'renotify_interval' => 60,
          'no_data_timeframe' => 20
        }
      }
      expect(subject.params_for_monitor(
               'monname',
               'my_msg',
               'my_query',
               123.4
      )).to eq(expected)
    end
    it 'sets escalation_message if provided in options' do
      expected = {
        'name' => 'monname',
        'type' => 'metric alert',
        'query' => 'my_query',
        'message' => 'my_msg',
        'tags' => [],
        'options' => {
          'notify_audit' => false,
          'locked' => false,
          'timeout_h' => 0,
          'silenced' => {},
          'thresholds' => { 'critical' => 123.4 },
          'require_full_window' => false,
          'notify_no_data' => true,
          'renotify_interval' => 60,
          'no_data_timeframe' => 20,
          'escalation_message' => 'myesc'
        }
      }
      expect(subject.params_for_monitor(
               'monname',
               'my_msg',
               'my_query',
               123.4,
               escalation_message: 'myesc'
      )).to eq(expected)
    end
    it 'sets mon_type if provided in options' do
      expected = {
        'name' => 'monname',
        'type' => 'foo',
        'query' => 'my_query',
        'message' => 'my_msg',
        'tags' => [],
        'options' => {
          'notify_audit' => false,
          'locked' => false,
          'timeout_h' => 0,
          'silenced' => {},
          'thresholds' => { 'critical' => 123.4 },
          'require_full_window' => false,
          'notify_no_data' => true,
          'renotify_interval' => 60,
          'no_data_timeframe' => 20
        }
      }
      expect(subject.params_for_monitor(
               'monname',
               'my_msg',
               'my_query',
               123.4,
               mon_type: 'foo'
      )).to eq(expected)
    end
    it 'sets renotify_interval if provided in options' do
      expected = {
        'name' => 'monname',
        'type' => 'metric alert',
        'query' => 'my_query',
        'message' => 'my_msg',
        'tags' => [],
        'options' => {
          'notify_audit' => false,
          'locked' => false,
          'timeout_h' => 0,
          'silenced' => {},
          'thresholds' => { 'critical' => 123.4 },
          'require_full_window' => false,
          'notify_no_data' => true,
          'renotify_interval' => 120,
          'no_data_timeframe' => 20
        }
      }
      expect(subject.params_for_monitor(
               'monname',
               'my_msg',
               'my_query',
               123.4,
               renotify_interval: 120
      )).to eq(expected)
    end
    it 'passes through a threshold Hash' do
      expected = {
        'name' => 'monname',
        'type' => 'foo',
        'query' => 'my_query',
        'message' => 'my_msg',
        'tags' => [],
        'options' => {
          'notify_audit' => false,
          'locked' => false,
          'timeout_h' => 0,
          'silenced' => {},
          'thresholds' => {
            'warning' => 50,
            'critical' => 123.4,
            'ok' => 20
          },
          'require_full_window' => false,
          'notify_no_data' => true,
          'renotify_interval' => 60,
          'no_data_timeframe' => 20
        }
      }
      expect(subject.params_for_monitor(
               'monname',
               'my_msg',
               'my_query',
               {
                 'warning' => 50,
                 'critical' => 123.4,
                 'ok' => 20
               },
               mon_type: 'foo'
      )).to eq(expected)
    end
    it 'sets notify_no_data to false if provided in options' do
      expected = {
        'name' => 'monname',
        'type' => 'metric alert',
        'query' => 'my_query',
        'message' => 'my_msg',
        'tags' => [],
        'options' => {
          'notify_audit' => false,
          'locked' => false,
          'timeout_h' => 0,
          'silenced' => {},
          'thresholds' => { 'critical' => 123.4 },
          'require_full_window' => false,
          'notify_no_data' => false,
          'renotify_interval' => 60,
          'no_data_timeframe' => 20
        }
      }
      expect(subject.params_for_monitor(
               'monname',
               'my_msg',
               'my_query',
               123.4,
               alert_no_data: false
      )).to eq(expected)
    end
    it 'handles all options' do
      expected = {
        'name' => 'monname',
        'type' => 'foo',
        'query' => 'my_query',
        'message' => 'my_msg',
        'tags' => [],
        'options' => {
          'notify_audit' => false,
          'locked' => false,
          'timeout_h' => 0,
          'silenced' => {},
          'thresholds' => { 'critical' => 123.4 },
          'require_full_window' => false,
          'notify_no_data' => false,
          'renotify_interval' => 123,
          'no_data_timeframe' => 20,
          'escalation_message' => 'myesc'
        }
      }
      expect(subject.params_for_monitor(
               'monname',
               'my_msg',
               'my_query',
               123.4,
               alert_no_data: false,
               mon_type: 'foo',
               escalation_message: 'myesc',
               renotify_interval: 123
      )).to eq(expected)
    end
  end
  describe '#upsert_monitor' do
    it 'creates the monitor if it doesnt exist' do
      params = { 'foo' => 'bar', 'baz' => 'blam' }
      dog = double(Dogapi::Client)
      allow(dog).to receive(:update_monitor).with(any_args)
      subject.instance_variable_set('@dog', dog)
      allow(subject).to receive(:generate_messages).with(any_args)
        .and_return(%w(msg esc))
      allow(subject).to receive(:params_for_monitor).with(any_args)
        .and_return(params)
      allow(subject).to receive(:get_existing_monitor_by_name).with(any_args)
        .and_return(nil)
      allow(subject).to receive(:create_monitor).with(any_args)
        .and_return('12345')

      expect(dog).to_not receive(:update_monitor)
      expect(subject).to receive(:generate_messages).once.with('mname', '>=')
      expect(subject).to receive(:params_for_monitor).once
        .with('mname', 'msg', 'my_query', 123.4, escalation_message: 'esc',
                                                 alert_no_data: true,
                                                 mon_type: 'metric alert',
                                                 renotify_interval: 60)
      expect(subject).to receive(:get_existing_monitor_by_name).once
        .with('mname')
      expect(subject).to receive(:create_monitor).once
        .with('mname', params)

      expect(subject.upsert_monitor(
               'mname',
               'my_query',
               123.4,
               '>='
      )).to eq('12345')
    end
    it 'handles a hash threshold' do
      params = { 'foo' => 'bar', 'baz' => 'blam' }
      dog = double(Dogapi::Client)
      allow(dog).to receive(:update_monitor).with(any_args)
      subject.instance_variable_set('@dog', dog)
      allow(subject).to receive(:generate_messages).with(any_args)
        .and_return(%w(msg esc))
      allow(subject).to receive(:params_for_monitor).with(any_args)
        .and_return(params)
      allow(subject).to receive(:get_existing_monitor_by_name).with(any_args)
        .and_return(nil)
      allow(subject).to receive(:create_monitor).with(any_args)
        .and_return('12345')

      expect(dog).to_not receive(:update_monitor)
      expect(subject).to receive(:generate_messages).once.with('mname', '>=')
      expect(subject).to receive(:params_for_monitor).once
        .with('mname', 'msg', 'my_query', { 'warning' => 5.3, 'ok' => 1 },
              escalation_message: 'esc',
              alert_no_data: true,
              mon_type: 'metric alert',
              renotify_interval: 60)
      expect(subject).to receive(:get_existing_monitor_by_name).once
        .with('mname')
      expect(subject).to receive(:create_monitor).once
        .with('mname', params)

      expect(subject.upsert_monitor(
               'mname',
               'my_query',
               { 'warning' => 5.3, 'ok' => 1 },
               '>='
      )).to eq('12345')
    end
    it 'does nothing if it already exists with the right params' do
      params = { 'foo' => 'bar', 'baz' => 'blam' }
      existing = { 'foo' => 'bar', 'baz' => 'blam', 'id' => 'monid' }
      dog = double(Dogapi::Client)
      allow(dog).to receive(:update_monitor).with(any_args)
      subject.instance_variable_set('@dog', dog)
      allow(subject).to receive(:generate_messages).with(any_args)
        .and_return(%w(msg esc))
      allow(subject).to receive(:params_for_monitor).with(any_args)
        .and_return(params)
      allow(subject).to receive(:get_existing_monitor_by_name).with(any_args)
        .and_return(existing)
      allow(subject).to receive(:create_monitor).with(any_args)
        .and_return('12345')

      expect(dog).to_not receive(:update_monitor)
      expect(subject).to receive(:generate_messages).once.with('mname', '>=')
      expect(subject).to receive(:params_for_monitor).once
        .with('mname', 'msg', 'my_query', 123.4, escalation_message: 'esc',
                                                 alert_no_data: true,
                                                 mon_type: 'metric alert',
                                                 renotify_interval: 60)
      expect(subject).to receive(:get_existing_monitor_by_name).once
        .with('mname')
      expect(subject).to_not receive(:create_monitor)

      expect(subject.upsert_monitor(
               'mname',
               'my_query',
               123.4,
               '>='
      )).to eq('monid')
    end
    it 'updates the monitor if missing parameters' do
      params = {
        'foo' => 'bar',
        'baz' => 'blam',
        'blarg' => 'quux',
        'query' => 'my_query'
      }
      existing = {
        'foo' => 'bar',
        'baz' => 'blam',
        'query' => 'my_query',
        'id' => 'monid'
      }
      dog = double(Dogapi::Client)
      allow(dog).to receive(:update_monitor).with(any_args)
        .and_return(['200', {}])
      subject.instance_variable_set('@dog', dog)
      allow(subject).to receive(:generate_messages).with(any_args)
        .and_return(%w(msg esc))
      allow(subject).to receive(:params_for_monitor).with(any_args)
        .and_return(params)
      allow(subject).to receive(:get_existing_monitor_by_name).with(any_args)
        .and_return(existing)
      allow(subject).to receive(:create_monitor).with(any_args)
        .and_return('12345')

      expect(dog).to receive(:update_monitor).once
        .with('monid', 'my_query', params)
      expect(subject).to receive(:generate_messages).once.with('mname', '>=')
      expect(subject).to receive(:params_for_monitor).once
        .with('mname', 'msg', 'my_query', 123.4, escalation_message: 'esc',
                                                 alert_no_data: true,
                                                 mon_type: 'metric alert',
                                                 renotify_interval: 60)
      expect(subject).to receive(:get_existing_monitor_by_name).once
        .with('mname')
      expect(subject).to_not receive(:create_monitor)

      expect(subject.upsert_monitor(
               'mname',
               'my_query',
               123.4,
               '>='
      )).to eq('monid')
    end
    it 'updates the monitor if parameters differ' do
      params = { 'foo' => 'bar', 'baz' => 'blam', 'query' => 'my_query' }
      existing = {
        'foo' => 'bar',
        'baz' => 'blarg',
        'query' => 'my_query',
        'id' => 'monid'
      }
      dog = double(Dogapi::Client)
      allow(dog).to receive(:update_monitor).with(any_args)
        .and_return(['200', {}])
      subject.instance_variable_set('@dog', dog)
      allow(subject).to receive(:generate_messages).with(any_args)
        .and_return(%w(msg esc))
      allow(subject).to receive(:params_for_monitor).with(any_args)
        .and_return(params)
      allow(subject).to receive(:get_existing_monitor_by_name).with(any_args)
        .and_return(existing)
      allow(subject).to receive(:create_monitor).with(any_args)
        .and_return('12345')

      expect(dog).to receive(:update_monitor).once
        .with('monid', 'my_query', params)
      expect(subject).to receive(:generate_messages).once.with('mname', '>=')
      expect(subject).to receive(:params_for_monitor).once
        .with('mname', 'msg', 'my_query', 123.4, escalation_message: 'esc',
                                                 alert_no_data: true,
                                                 mon_type: 'metric alert',
                                                 renotify_interval: 60)
      expect(subject).to receive(:get_existing_monitor_by_name).once
        .with('mname')
      expect(subject).to_not receive(:create_monitor)

      expect(subject.upsert_monitor(
               'mname',
               'my_query',
               123.4,
               '>='
      )).to eq('monid')
    end
    it 'returns nil if the update failed' do
      params = {
        'foo' => 'bar',
        'baz' => 'blam',
        'blarg' => 'quux',
        'query' => 'my_query'
      }
      existing = {
        'foo' => 'bar',
        'baz' => 'blam',
        'query' => 'my_query',
        'id' => 'monid'
      }
      res = ['404', {}]
      dog = double(Dogapi::Client)
      allow(dog).to receive(:update_monitor).with(any_args).and_return(res)
      subject.instance_variable_set('@dog', dog)
      allow(subject).to receive(:generate_messages).with(any_args)
        .and_return(%w(msg esc))
      allow(subject).to receive(:params_for_monitor).with(any_args)
        .and_return(params)
      allow(subject).to receive(:get_existing_monitor_by_name).with(any_args)
        .and_return(existing)
      allow(subject).to receive(:create_monitor).with(any_args)
        .and_return('12345')
      allow(subject.logger).to receive(:debug).with(any_args)
      allow(subject.logger).to receive(:info).with(any_args)
      allow(subject.logger).to receive(:error).with(any_args)

      expect(dog).to receive(:update_monitor).once
        .with('monid', 'my_query', params)
      expect(subject).to receive(:generate_messages).once.with('mname', '>=')
      expect(subject).to receive(:params_for_monitor).once
        .with('mname', 'msg', 'my_query', 123.4, escalation_message: 'esc',
                                                 alert_no_data: true,
                                                 mon_type: 'metric alert',
                                                 renotify_interval: 60)
      expect(subject).to receive(:get_existing_monitor_by_name).once
        .with('mname')
      expect(subject).to_not receive(:create_monitor)
      expect(subject.logger).to receive(:error).once
        .with("\tError updating monitor monid: #{res}")

      expect(subject.upsert_monitor(
               'mname',
               'my_query',
               123.4,
               '>='
      )).to be_nil
    end
    it 'handles sparse options, with only alert_no_data' do
      params = { 'foo' => 'bar', 'baz' => 'blam' }
      existing = { 'foo' => 'bar', 'baz' => 'blam', 'id' => 'monid' }
      dog = double(Dogapi::Client)
      allow(dog).to receive(:update_monitor).with(any_args)
      subject.instance_variable_set('@dog', dog)
      allow(subject).to receive(:generate_messages).with(any_args)
        .and_return(%w(msg esc))
      allow(subject).to receive(:params_for_monitor).with(any_args)
        .and_return(params)
      allow(subject).to receive(:get_existing_monitor_by_name).with(any_args)
        .and_return(existing)
      allow(subject).to receive(:create_monitor).with(any_args)
        .and_return('12345')

      expect(dog).to_not receive(:update_monitor)
      expect(subject).to receive(:generate_messages).once.with('mname', '>=')
      expect(subject).to receive(:params_for_monitor).once
        .with('mname', 'msg', 'my_query', 123.4, escalation_message: 'esc',
                                                 alert_no_data: false,
                                                 mon_type: 'metric alert',
                                                 renotify_interval: 60)
      expect(subject).to receive(:get_existing_monitor_by_name).once
        .with('mname')
      expect(subject).to_not receive(:create_monitor)

      expect(subject.upsert_monitor(
               'mname',
               'my_query',
               123.4,
               '>=',
               alert_no_data: false
      )).to eq('monid')
    end
    it 'handles sparse options, with only mon_type' do
      params = { 'foo' => 'bar', 'baz' => 'blam' }
      existing = { 'foo' => 'bar', 'baz' => 'blam', 'id' => 'monid' }
      dog = double(Dogapi::Client)
      allow(dog).to receive(:update_monitor).with(any_args)
      subject.instance_variable_set('@dog', dog)
      allow(subject).to receive(:generate_messages).with(any_args)
        .and_return(%w(msg esc))
      allow(subject).to receive(:params_for_monitor).with(any_args)
        .and_return(params)
      allow(subject).to receive(:get_existing_monitor_by_name).with(any_args)
        .and_return(existing)
      allow(subject).to receive(:create_monitor).with(any_args)
        .and_return('12345')

      expect(dog).to_not receive(:update_monitor)
      expect(subject).to receive(:generate_messages).once.with('mname', '>=')
      expect(subject).to receive(:params_for_monitor).once
        .with('mname', 'msg', 'my_query', 123.4, escalation_message: 'esc',
                                                 alert_no_data: true,
                                                 mon_type: 'foobar',
                                                 renotify_interval: 60)
      expect(subject).to receive(:get_existing_monitor_by_name).once
        .with('mname')
      expect(subject).to_not receive(:create_monitor)

      expect(subject.upsert_monitor(
               'mname',
               'my_query',
               123.4,
               '>=',
               mon_type: 'foobar'
      )).to eq('monid')
    end
    it 'handles sparse options, with only renotify_interval' do
      params = { 'foo' => 'bar', 'baz' => 'blam' }
      existing = { 'foo' => 'bar', 'baz' => 'blam', 'id' => 'monid' }
      dog = double(Dogapi::Client)
      allow(dog).to receive(:update_monitor).with(any_args)
      subject.instance_variable_set('@dog', dog)
      allow(subject).to receive(:generate_messages).with(any_args)
        .and_return(%w(msg esc))
      allow(subject).to receive(:params_for_monitor).with(any_args)
        .and_return(params)
      allow(subject).to receive(:get_existing_monitor_by_name).with(any_args)
        .and_return(existing)
      allow(subject).to receive(:create_monitor).with(any_args)
        .and_return('12345')

      expect(dog).to_not receive(:update_monitor)
      expect(subject).to receive(:generate_messages).once.with('mname', '>=')
      expect(subject).to receive(:params_for_monitor).once
        .with('mname', 'msg', 'my_query', 123.4, escalation_message: 'esc',
                                                 alert_no_data: true,
                                                 mon_type: 'metric alert',
                                                 renotify_interval: 100)
      expect(subject).to receive(:get_existing_monitor_by_name).once
        .with('mname')
      expect(subject).to_not receive(:create_monitor)

      expect(subject.upsert_monitor(
               'mname',
               'my_query',
               123.4,
               '>=',
               renotify_interval: 100
      )).to eq('monid')
    end
    it 'handles all options' do
      params = { 'foo' => 'bar', 'baz' => 'blam' }
      existing = { 'foo' => 'bar', 'baz' => 'blam', 'id' => 'monid' }
      dog = double(Dogapi::Client)
      allow(dog).to receive(:update_monitor).with(any_args)
      subject.instance_variable_set('@dog', dog)
      allow(subject).to receive(:generate_messages).with(any_args)
        .and_return(%w(msg esc))
      allow(subject).to receive(:params_for_monitor).with(any_args)
        .and_return(params)
      allow(subject).to receive(:get_existing_monitor_by_name).with(any_args)
        .and_return(existing)
      allow(subject).to receive(:create_monitor).with(any_args)
        .and_return('12345')

      expect(dog).to_not receive(:update_monitor)
      expect(subject).to receive(:generate_messages).once.with('mname', '>=')
      expect(subject).to receive(:params_for_monitor).once
        .with('mname', 'msg', 'my_query', 123.4, escalation_message: 'esc',
                                                 alert_no_data: false,
                                                 mon_type: 'service check',
                                                 renotify_interval: 10)
      expect(subject).to receive(:get_existing_monitor_by_name).once
        .with('mname')
      expect(subject).to_not receive(:create_monitor)

      expect(subject.upsert_monitor(
               'mname',
               'my_query',
               123.4,
               '>=',
               renotify_interval: 10,
               alert_no_data: false,
               mon_type: 'service check'
      )).to eq('monid')
    end
  end
  describe '#create_monitor' do
    it 'returns the monitor id if created successfully' do
      res = ['200', { 'foo' => 'bar', 'id' => 'monid' }]
      params = { 'type' => 't', 'query' => 'q', 'foo' => 'bar' }
      dog = double(Dogapi::Client)
      allow(dog).to receive(:monitor).with(any_args).and_return(res)
      subject.instance_variable_set('@dog', dog)
      allow(subject.logger).to receive(:error).with(any_args)

      expect(dog).to receive(:monitor).once
        .with(params['type'], params['query'], params)
      expect(subject.logger).to_not receive(:error)
      expect(subject.create_monitor('foo', params)).to eq('monid')
    end
    it 'logs an error and returns nil if the create fails' do
      res = ['404', {}]
      params = { 'type' => 't', 'query' => 'q', 'foo' => 'bar' }
      dog = double(Dogapi::Client)
      allow(dog).to receive(:monitor).with(any_args).and_return(res)
      subject.instance_variable_set('@dog', dog)
      allow(subject.logger).to receive(:error).with(any_args)

      expect(dog).to receive(:monitor).once
        .with(params['type'], params['query'], params)
      expect(subject.logger).to receive(:error).once
        .with("\tError creating monitor: #{res}")
      expect(subject.create_monitor('foo', params)).to be_nil
    end
  end
  describe '#get_existing_monitor_by_name' do
    it 'retrieves monitors if they are not cached' do
      monitors = [
        '200',
        [
          { 'name' => 'foo', 'foo' => 'bar' },
          { 'name' => 'bar', 'foo' => 'baz' }
        ]
      ]
      dog = double(Dogapi::Client)
      allow(dog).to receive(:get_all_monitors).with(any_args)
        .and_return(monitors)
      subject.instance_variable_set('@dog', dog)

      expect(dog).to receive(:get_all_monitors).once.with(group_states: 'all')
      expect(subject.get_existing_monitor_by_name('bar'))
        .to eq('name' => 'bar', 'foo' => 'baz')
      expect(subject.instance_variable_get('@monitors')).to eq(monitors)
    end
    it 'does not retrieve monitors if they are cached' do
      monitors = [
        '200',
        [
          { 'name' => 'foo', 'foo' => 'bar' },
          { 'name' => 'bar', 'foo' => 'baz' }
        ]
      ]
      dog = double(Dogapi::Client)
      allow(dog).to receive(:get_all_monitors).with(any_args)
        .and_return(monitors)
      subject.instance_variable_set('@dog', dog)
      subject.instance_variable_set('@monitors', monitors)

      expect(dog).to_not receive(:get_all_monitors)
      expect(subject.get_existing_monitor_by_name('bar'))
        .to eq('name' => 'bar', 'foo' => 'baz')
      expect(subject.instance_variable_get('@monitors')).to eq(monitors)
    end
    it 'exits if no monitors can be found' do
      monitors = ['200', []]
      dog = double(Dogapi::Client)
      allow(dog).to receive(:get_all_monitors).with(any_args)
        .and_return(monitors)
      subject.instance_variable_set('@dog', dog)
      allow(subject.logger).to receive(:error).with(any_args)

      expect(dog).to receive(:get_all_monitors).once
        .with(group_states: 'all')
      expect(subject.logger).to receive(:error).once
        .with('ERROR: Docker API call returned no existing monitors. ' \
          'Something is wrong.')
      expect { subject.get_existing_monitor_by_name('bar') }
        .to raise_error(SystemExit)
    end
  end
  describe '#graphdef' do
    it 'generates a graphdef with sensible defaults' do
      expected = {
        'definition' => {
          'viz' => 'timeseries',
          'requests' => [
            {
              'q' => 'query1',
              'conditional_formats' => [],
              'type' => 'line'
            }
          ]
        },
        'title' => 'gtitle'
      }
      expect(subject.graphdef('gtitle', 'query1')).to eq(expected)
    end
    it 'handles an array of queries' do
      expected = {
        'definition' => {
          'viz' => 'timeseries',
          'requests' => [
            {
              'q' => 'query1',
              'conditional_formats' => [],
              'type' => 'line'
            },
            {
              'q' => 'query2',
              'conditional_formats' => [],
              'type' => 'line'
            },
            {
              'q' => 'query3',
              'conditional_formats' => [],
              'type' => 'line'
            }
          ]
        },
        'title' => 'gtitle'
      }
      expect(
        subject.graphdef('gtitle', %w(query1 query2 query3))
      ).to eq(expected)
    end
    it 'adds markers if specified' do
      expected = {
        'definition' => {
          'viz' => 'timeseries',
          'requests' => [
            {
              'q' => 'query1',
              'conditional_formats' => [],
              'type' => 'line'
            }
          ],
          'markers' => [
            {
              'type' => 'error dashed',
              'val' => '2.3',
              'value' => 'y = 2.3',
              'label' => 'marker1==2.3'
            },
            {
              'type' => 'error dashed',
              'val' => '45',
              'value' => 'y = 45',
              'label' => 'm2==45'
            }
          ]
        },
        'title' => 'gtitle'
      }
      expect(
        subject.graphdef('gtitle', 'query1', 'marker1' => 2.3, 'm2' => 45)
      ).to eq(expected)
    end
  end
  describe '#upsert_timeboard' do
    it 'creates the timeboard if it doesnt exist' do
      res = [
        '200',
        {
          'foo' => 'bar',
          'dash' => {
            'id' => 'id1',
            'description' => 'created by DogTrainer RubyGem via my_repo_path',
            'title' => 't',
            'graphs' => [1, 2]
          }
        }
      ]
      dog = double(Dogapi::Client)
      allow(dog).to receive(:create_dashboard).with(any_args).and_return(res)
      allow(dog).to receive(:update_dashboard).with(any_args)
      subject.instance_variable_set('@dog', dog)
      allow(subject).to receive(:get_existing_timeboard_by_name).with(any_args)
        .and_return(nil)
      allow(subject.logger).to receive(:info).with(any_args)

      expect(subject).to receive(:get_existing_timeboard_by_name).once
        .with('t')
      expect(dog).to receive(:create_dashboard).once
        .with(
          't',
          'created by DogTrainer RubyGem via my_repo_path',
          [1, 2]
        )
      expect(dog).to_not receive(:update_dashboard)
      expect(subject.logger).to receive(:info).with('Created timeboard id1')
      subject.upsert_timeboard('t', [1, 2])
    end
    it 'does not update if params are current' do
      res = [
        '200',
        {
          'foo' => 'bar',
          'dash' => {
            'id' => 'id1',
            'description' => 'created by DogTrainer RubyGem via my_repo_path',
            'title' => 't',
            'graphs' => [1, 2]
          }
        }
      ]
      dog = double(Dogapi::Client)
      allow(dog).to receive(:create_dashboard).with(any_args)
      allow(dog).to receive(:update_dashboard).with(any_args)
      subject.instance_variable_set('@dog', dog)
      allow(subject).to receive(:get_existing_timeboard_by_name).with(any_args)
        .and_return(res[1])
      allow(subject.logger).to receive(:info).with(any_args)

      expect(subject).to receive(:get_existing_timeboard_by_name).once
        .with('t')
      expect(dog).to_not receive(:create_dashboard)
      expect(dog).to_not receive(:update_dashboard)
      expect(subject.logger).to receive(:info).with("\tTimeboard is up-to-date")
      subject.upsert_timeboard('t', [1, 2])
    end
    it 'updates if title changed' do
      res = [
        '200',
        {
          'foo' => 'bar',
          'dash' => {
            'id' => 'id1',
            'description' => 'created by DogTrainer RubyGem via my_repo_path',
            'title' => 'not_t',
            'graphs' => [1, 2]
          }
        }
      ]
      dog = double(Dogapi::Client)
      allow(dog).to receive(:create_dashboard).with(any_args)
      allow(dog).to receive(:update_dashboard).with(any_args)
      subject.instance_variable_set('@dog', dog)
      allow(subject).to receive(:get_existing_timeboard_by_name).with(any_args)
        .and_return(res[1])
      allow(subject.logger).to receive(:info).with(any_args)

      expect(subject).to receive(:get_existing_timeboard_by_name).once
        .with('t')
      expect(dog).to_not receive(:create_dashboard)
      expect(dog).to receive(:update_dashboard).once.with(
        res[1]['dash']['id'],
        't',
        res[1]['dash']['description'],
        res[1]['dash']['graphs']
      )
      expect(subject.logger).to receive(:info).with("\tUpdating timeboard id1")
      expect(subject.logger).to receive(:info).with("\tTimeboard updated.")
      subject.upsert_timeboard('t', [1, 2])
    end
    it 'updates if repo_path changed' do
      res = [
        '200',
        {
          'foo' => 'bar',
          'dash' => {
            'id' => 'id1',
            'description' => 'created by DogTrainer RubyGem via otherpath',
            'title' => 't',
            'graphs' => [1, 2]
          }
        }
      ]
      dog = double(Dogapi::Client)
      allow(dog).to receive(:create_dashboard).with(any_args)
      allow(dog).to receive(:update_dashboard).with(any_args)
      subject.instance_variable_set('@dog', dog)
      allow(subject).to receive(:get_existing_timeboard_by_name).with(any_args)
        .and_return(res[1])
      allow(subject.logger).to receive(:info).with(any_args)

      expect(subject).to receive(:get_existing_timeboard_by_name).once
        .with('t')
      expect(dog).to_not receive(:create_dashboard)
      expect(dog).to receive(:update_dashboard).once.with(
        res[1]['dash']['id'],
        res[1]['dash']['title'],
        'created by DogTrainer RubyGem via my_repo_path',
        res[1]['dash']['graphs']
      )
      expect(subject.logger).to receive(:info).with("\tUpdating timeboard id1")
      expect(subject.logger).to receive(:info).with("\tTimeboard updated.")
      subject.upsert_timeboard('t', [1, 2])
    end
    it 'updates if graphs changed' do
      res = [
        '200',
        {
          'foo' => 'bar',
          'dash' => {
            'id' => 'id1',
            'description' => 'created by DogTrainer RubyGem via my_repo_path',
            'title' => 't',
            'graphs' => [1, 2]
          }
        }
      ]
      dog = double(Dogapi::Client)
      allow(dog).to receive(:create_dashboard).with(any_args)
      allow(dog).to receive(:update_dashboard).with(any_args)
      subject.instance_variable_set('@dog', dog)
      allow(subject).to receive(:get_existing_timeboard_by_name).with(any_args)
        .and_return(res[1])
      allow(subject.logger).to receive(:info).with(any_args)

      expect(subject).to receive(:get_existing_timeboard_by_name).once
        .with('t')
      expect(dog).to_not receive(:create_dashboard)
      expect(dog).to receive(:update_dashboard).once.with(
        res[1]['dash']['id'],
        res[1]['dash']['title'],
        res[1]['dash']['description'],
        [3, 4]
      )
      expect(subject.logger).to receive(:info).with("\tUpdating timeboard id1")
      expect(subject.logger).to receive(:info).with("\tTimeboard updated.")
      subject.upsert_timeboard('t', [3, 4])
    end
  end
  describe '#upsert_screenboard' do
    it 'creates the screenboard if it doesnt exist' do
      res = [
        '200',
        {
          'id' => 'id1',
          'description' => 'created by DogTrainer RubyGem via my_repo_path',
          'board_title' => 't',
          'widgets' => [1, 2]
        }
      ]
      dog = double(Dogapi::Client)
      allow(dog).to receive(:create_screenboard).with(any_args).and_return(res)
      allow(dog).to receive(:update_screenboard).with(any_args)
      subject.instance_variable_set('@dog', dog)
      allow(subject).to receive(:get_existing_screenboard_by_name)
        .with(any_args).and_return(nil)
      allow(subject.logger).to receive(:info).with(any_args)

      expect(subject).to receive(:get_existing_screenboard_by_name).once
        .with('t')
      expect(dog).to receive(:create_screenboard).once
        .with(
          board_title: 't',
          description: 'created by DogTrainer RubyGem via my_repo_path',
          widgets: [1, 2]
        )
      expect(dog).to_not receive(:update_screenboard)
      expect(subject.logger).to receive(:info).with('Created screenboard id1')
      subject.upsert_screenboard('t', [1, 2])
    end
    it 'does nothing if it is up to date' do
      res = [
        '200',
        {
          'id' => 'id1',
          'description' => 'created by DogTrainer RubyGem via my_repo_path',
          'board_title' => 't',
          'widgets' => [1, 2]
        }
      ]
      dog = double(Dogapi::Client)
      allow(dog).to receive(:create_screenboard).with(any_args)
      allow(dog).to receive(:update_screenboard).with(any_args)
      subject.instance_variable_set('@dog', dog)
      allow(subject).to receive(:get_existing_screenboard_by_name)
        .with(any_args).and_return(res[1])
      allow(subject.logger).to receive(:info).with(any_args)

      expect(subject).to receive(:get_existing_screenboard_by_name).once
        .with('t')
      expect(dog).to_not receive(:create_screenboard)
      expect(dog).to_not receive(:update_screenboard)
      expect(subject.logger).to receive(:info)
        .with("\tScreenboard is up-to-date")
      subject.upsert_screenboard('t', [1, 2])
    end
    it 'updates if repo_path in description is different' do
      res = [
        '200',
        {
          'id' => 'id1',
          'description' => 'created by DogTrainer RubyGem via foo',
          'board_title' => 't',
          'widgets' => [1, 2]
        }
      ]
      dog = double(Dogapi::Client)
      allow(dog).to receive(:create_screenboard).with(any_args)
      allow(dog).to receive(:update_screenboard).with(any_args)
      subject.instance_variable_set('@dog', dog)
      allow(subject).to receive(:get_existing_screenboard_by_name)
        .with(any_args).and_return(res[1])
      allow(subject.logger).to receive(:info).with(any_args)

      expect(subject).to receive(:get_existing_screenboard_by_name).once
        .with('t')
      expect(dog).to_not receive(:create_screenboard)
      expect(dog).to_not receive(:update_screenboard).once
        .with(
          'id1',
          board_title: 't',
          description: 'created by DogTrainer RubyGem via my_repo_path',
          widgets: [1, 2]
        )
      subject.upsert_screenboard('t', [1, 2])
    end
    it 'updates if title is different' do
      res = [
        '200',
        {
          'id' => 'id1',
          'description' => 'created by DogTrainer RubyGem via foo',
          'board_title' => 'not_t',
          'widgets' => [1, 2]
        }
      ]
      dog = double(Dogapi::Client)
      allow(dog).to receive(:create_screenboard).with(any_args)
      allow(dog).to receive(:update_screenboard).with(any_args)
      subject.instance_variable_set('@dog', dog)
      allow(subject).to receive(:get_existing_screenboard_by_name)
        .with(any_args).and_return(res[1])
      allow(subject.logger).to receive(:info).with(any_args)

      expect(subject).to receive(:get_existing_screenboard_by_name).once
        .with('t')
      expect(dog).to_not receive(:create_screenboard)
      expect(dog).to_not receive(:update_screenboard).once
        .with(
          'id1',
          board_title: 't',
          description: 'created by DogTrainer RubyGem via my_repo_path',
          widgets: [1, 2]
        )
      subject.upsert_screenboard('t', [1, 2])
    end
    it 'updates if widgets are different' do
      res = [
        '200',
        {
          'id' => 'id1',
          'description' => 'created by DogTrainer RubyGem via foo',
          'board_title' => 't',
          'widgets' => [3, 4]
        }
      ]
      dog = double(Dogapi::Client)
      allow(dog).to receive(:create_screenboard).with(any_args)
      allow(dog).to receive(:update_screenboard).with(any_args)
      subject.instance_variable_set('@dog', dog)
      allow(subject).to receive(:get_existing_screenboard_by_name)
        .with(any_args).and_return(res[1])
      allow(subject.logger).to receive(:info).with(any_args)

      expect(subject).to receive(:get_existing_screenboard_by_name).once
        .with('t')
      expect(dog).to_not receive(:create_screenboard)
      expect(dog).to_not receive(:update_screenboard).once
        .with(
          'id1',
          board_title: 't',
          description: 'created by DogTrainer RubyGem via my_repo_path',
          widgets: [1, 2]
        )
      subject.upsert_screenboard('t', [1, 2])
    end
  end
  describe '#get_existing_timeboard_by_name' do
    it 'retrieves timeboards if they are not cached' do
      boards = [
        '200',
        {
          'dashes' => [
            { 'title' => 'foo', 'id' => 'dash1' },
            { 'title' => 'bar', 'id' => 'dash2' }
          ]
        }
      ]
      board = ['200', { 'foo' => 'bar', 'baz' => 'blam' }]
      dog = double(Dogapi::Client)
      allow(dog).to receive(:get_dashboards).with(any_args)
        .and_return(boards)
      allow(dog).to receive(:get_dashboard).with(any_args).and_return(board)
      subject.instance_variable_set('@dog', dog)

      expect(dog).to receive(:get_dashboards).once
      expect(dog).to receive(:get_dashboard).once.with('dash2')
      expect(subject.get_existing_timeboard_by_name('bar'))
        .to eq(board[1])
      expect(subject.instance_variable_get('@timeboards')).to eq(boards)
    end
    it 'does not retrieve boards if they are cached' do
      boards = [
        '200',
        {
          'dashes' => [
            { 'title' => 'foo', 'id' => 'dash1' },
            { 'title' => 'bar', 'id' => 'dash2' }
          ]
        }
      ]
      board = ['200', { 'foo' => 'bar', 'baz' => 'blam' }]
      dog = double(Dogapi::Client)
      allow(dog).to receive(:get_dashboards).with(any_args)
        .and_return(boards)
      allow(dog).to receive(:get_dashboard).with(any_args).and_return(board)
      subject.instance_variable_set('@dog', dog)
      subject.instance_variable_set('@timeboards', boards)

      expect(dog).to_not receive(:get_dashboards)
      expect(dog).to receive(:get_dashboard).once.with('dash2')
      expect(subject.get_existing_timeboard_by_name('bar'))
        .to eq(board[1])
      expect(subject.instance_variable_get('@timeboards')).to eq(boards)
    end
    it 'returns nil if no matching board can be found' do
      boards = [
        '200',
        {
          'dashes' => [
            { 'title' => 'foo', 'id' => 'dash1' },
            { 'title' => 'bar', 'id' => 'dash2' }
          ]
        }
      ]
      board = ['200', { 'foo' => 'bar', 'baz' => 'blam' }]
      dog = double(Dogapi::Client)
      allow(dog).to receive(:get_dashboards).with(any_args)
        .and_return(boards)
      allow(dog).to receive(:get_dashboard).with(any_args).and_return(board)
      subject.instance_variable_set('@dog', dog)
      subject.instance_variable_set('@timeboards', boards)

      expect(dog).to_not receive(:get_dashboards)
      expect(dog).to_not receive(:get_dashboard)
      expect(subject.get_existing_timeboard_by_name('blam'))
        .to be_nil
      expect(subject.instance_variable_get('@timeboards')).to eq(boards)
    end
    it 'exits if no boards can be found' do
      boards = [
        '200',
        {
          'dashes' => []
        }
      ]
      dog = double(Dogapi::Client)
      allow(dog).to receive(:get_dashboards).with(any_args)
        .and_return(boards)
      allow(dog).to receive(:get_dashboard).with(any_args)
      subject.instance_variable_set('@dog', dog)

      expect(dog).to receive(:get_dashboards).once
      expect(dog).to_not receive(:get_dashboard)
      expect { subject.get_existing_timeboard_by_name('blam') }
        .to raise_error(SystemExit)
    end
  end
  describe '#get_existing_screenboard_by_name' do
    it 'retrieves screenboards if they are not cached' do
      boards = [
        '200',
        {
          'screenboards' => [
            { 'title' => 'foo', 'id' => 'screen1' },
            { 'title' => 'bar', 'id' => 'screen2' }
          ]
        }
      ]
      board = ['200', { 'foo' => 'bar', 'baz' => 'blam' }]
      dog = double(Dogapi::Client)
      allow(dog).to receive(:get_all_screenboards).with(any_args)
        .and_return(boards)
      allow(dog).to receive(:get_screenboard).with(any_args).and_return(board)
      subject.instance_variable_set('@dog', dog)

      expect(dog).to receive(:get_all_screenboards).once
      expect(dog).to receive(:get_screenboard).once.with('screen2')
      expect(subject.get_existing_screenboard_by_name('bar'))
        .to eq(board[1])
      expect(subject.instance_variable_get('@screenboards')).to eq(boards)
    end
    it 'does not retrieve boards if they are cached' do
      boards = [
        '200',
        {
          'screenboards' => [
            { 'title' => 'foo', 'id' => 'screen1' },
            { 'title' => 'bar', 'id' => 'screen2' }
          ]
        }
      ]
      board = ['200', { 'foo' => 'bar', 'baz' => 'blam' }]
      dog = double(Dogapi::Client)
      allow(dog).to receive(:get_all_screenboards).with(any_args)
        .and_return(boards)
      allow(dog).to receive(:get_screenboard).with(any_args).and_return(board)
      subject.instance_variable_set('@dog', dog)
      subject.instance_variable_set('@screenboards', boards)

      expect(dog).to_not receive(:get_all_screenboards)
      expect(dog).to receive(:get_screenboard).once.with('screen2')
      expect(subject.get_existing_screenboard_by_name('bar'))
        .to eq(board[1])
      expect(subject.instance_variable_get('@screenboards')).to eq(boards)
    end
    it 'returns nil if no matching board can be found' do
      boards = [
        '200',
        {
          'screenboards' => [
            { 'title' => 'foo', 'id' => 'screen1' },
            { 'title' => 'bar', 'id' => 'screen2' }
          ]
        }
      ]
      board = ['200', { 'foo' => 'bar', 'baz' => 'blam' }]
      dog = double(Dogapi::Client)
      allow(dog).to receive(:get_all_screenboards).with(any_args)
        .and_return(boards)
      allow(dog).to receive(:get_screenboard).with(any_args).and_return(board)
      subject.instance_variable_set('@dog', dog)
      subject.instance_variable_set('@screenboards', boards)

      expect(dog).to_not receive(:get_all_screenboards)
      expect(dog).to_not receive(:get_screenboard)
      expect(subject.get_existing_screenboard_by_name('blam'))
        .to be_nil
      expect(subject.instance_variable_get('@screenboards')).to eq(boards)
    end
    it 'exits if no boards can be found' do
      boards = [
        '200',
        {
          'screenboards' => []
        }
      ]
      dog = double(Dogapi::Client)
      allow(dog).to receive(:get_all_screenboards).with(any_args)
        .and_return(boards)
      allow(dog).to receive(:get_screenboard).with(any_args)
      subject.instance_variable_set('@dog', dog)

      expect(dog).to receive(:get_all_screenboards).once
      expect(dog).to_not receive(:get_screenboard)
      expect { subject.get_existing_screenboard_by_name('blam') }
        .to raise_error(SystemExit)
    end
  end
end
