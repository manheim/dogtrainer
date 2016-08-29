# -*- encoding: utf-8 -*-
require File.expand_path('../lib/dogtrainer/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors     = ['Jason Antman']
  gem.email       = ['jason.antman@manheim.com']
  gem.description = 'TODO: fill in full description here'
  gem.summary     = 'Wrapper around DataDog dogapi gem to simplify creation and management of Monitors and Boards'
  gem.homepage    = 'http://github.com/Manheim/dogtrainer'
  gem.license     = 'unknown'

  gem.executables << 'dogtrainer'

  # uncomment once released:
  # gem.add_development_dependency 'manheim_helpers'

  # ensure gem will only push to our Artifactory
  # this requires rubygems >= 2.2.0
  gem.metadata['allowed_push_host'] = 'https://artifactory.aws-dev.manheim.com/artifactory/api/gems/gems-local'

  gem.files         = `git ls-files`.split($ORS)
                                    .reject { |f| f =~ %r{^samples\/} }
  gem.executables   = gem.files.grep(%r{^bin/}).map { |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = 'dogtrainer'
  gem.require_paths = ['lib']
  gem.version       = DogTrainer::VERSION
end
