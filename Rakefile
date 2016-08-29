require 'rubygems'
require 'manheim_helpers/gem/raketasks'

ManheimHelpers::Gem::RakeTasks.install_tasks(
  File.join(File.expand_path(File.dirname(__FILE__)), 'dogtrainer.gemspec'),
  # don't tag git repo and push tag after publish:
  # git_tag: false,
  # don't fail publish if newer or equal version already in Artifactory:
  # check_version: false,
    # restrict publishing on CircleCI to repos owned by 'Manheim':
  circle_username: 'Manheim',
  # restrict publishing from CircleCI to repos named 'dogtrainer':
  circle_reponame: 'dogtrainer',
    # restrict publishing from CircleCI to the 'master' branch:
  circle_branch: 'master',
  # don't populate ~/.gem/credentials using ``ARTIFACTORY_USER`` and
  #   `ARTIFACTORY_PASSWORD`` to retrieve creds from Artifactory:
  # set_credentials: false,
  # don't add YARD documentation Rake tasks:
  # add_yard: false,
  # don't add RSpec Rake tasks:
  # add_rspec: false,
  # don't add RuboCop Rake tasks:
  # add_rubocop: false,
  # don't add a 'help' Rake task to run 'rake -T':
  # add_help: false,
  # don't make the 'help' task the default:
  # help_default: false
)
