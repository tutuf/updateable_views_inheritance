# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

require 'warning'
Warning.ignore(/.*in Ruby 3.*/)

# test coverage
require 'simplecov'
require 'simplecov_json_formatter'

SimpleCov.start 'rails' do
  if ENV['CI']
    formatter SimpleCov::Formatter::JSONFormatter
  else
    formatter SimpleCov::Formatter::MultiFormatter.new([
      SimpleCov::Formatter::SimpleFormatter,
      SimpleCov::Formatter::HTMLFormatter
    ])
  end

  track_files "lib/**/*.rb"
  # repeat the add_filter values in sonar-project.properties file
  # otherwise sonarcloud does not calculate properly the coverage ratio
  add_filter "lib/generators/updateable_views_inheritance/templates/create_updateable_views_inheritance.rb"
  add_filter "lib/updateable_views_inheritance/version.rb"
end

require File.expand_path("../dummy/config/environment.rb",  __FILE__)
require 'rails/test_help'
require 'updateable_views_inheritance'

require 'byebug'

class ActiveSupport::TestCase #:nodoc:
  include ActiveRecord::TestFixtures
  ActiveRecord::Migration.verbose = false

  # def teardown
  #   ActiveRecord::Migrator.down(File.dirname(__FILE__) + '/fixtures/migrations/', 1)
  #   ActiveRecord::FixtureSet.reset_cache
  # end
end

# # Useful for debugging flaky tests that depend on order of other tests
# require "minitest/reporters"
# Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new
