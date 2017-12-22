Version 0.4.1

  - Upgrade rubocop and yard development dependency versions
  - Pin `cri` development dependency to 2.9 to retain ruby 2.0 support

Version 0.4.0

  - Added support for ``:no_data_timeframe`` and ``:evaluation_delay`` options
    on monitors.

Version 0.3.0

  - Added ``DogTrainer::DogApiException`` custom exception class, subclass of ``StandardError``.
  - ``DogTrainer::API`` methods ``mute_monitor_by_id``, ``mute_monitor_by_name``,
    ``mute_monitors_by_regex``, ``unmute_monitor_by_id``, ``unmute_monitor_by_name``,
    ``unmute_monitors_by_regex``, ``upsert_timeboard`` and ``upsert_screenboard``
    now raise an ``DogTrainer::DogApiException`` if the Datadog API response status
    code indicates an error.

Version 0.2.0

  - add support to mute and unmute monitors by id, name or regex

Version 0.1.1

  - add ``message`` and ``escalation_message`` options to ``DogTrainer::API.upsert_monitor``
    to allow user to easily override either or both of these
  - handle a ``threshold`` Hash passed to ``DogTrainer::API.upsert_monitor`` and
    ``DogTrainer::API.params_for_monitor``
  - expose ``renotify_interval`` as an option on ``DogTrainer::API.upsert_monitor``
  - pass ``mon_type`` through to ``DogTrainer::API.generate_messages`` and generate
    different messages for service checks (which have warning or alert)

Version 0.1.0

  - initial release
