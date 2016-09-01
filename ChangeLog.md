Version 0.1.1

  - add ``message`` and ``escalation_message`` options to ``DogTrainer::API.upsert_monitor``
    to allow user to easily override either or both of these
  - handle a ``threshold`` Hash passed to ``DogTrainer::API.upsert_monitor`` and
    ``DogTrainer::API.params_for_monitor``
  - expose ``renotify_interval`` as an option on ``DogTrainer::API.upsert_monitor``

Version 0.1.0

  - initial release
