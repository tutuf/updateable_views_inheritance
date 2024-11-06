# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

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
  self.fixture_path = "#{File.dirname(__FILE__)}/fixtures/"
  ActiveRecord::Migration.verbose = false
end
