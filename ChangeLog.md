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
