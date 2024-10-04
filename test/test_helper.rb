# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

# test coverage
require 'simplecov'
require 'simplecov-lcov'

SimpleCov::Formatter::LcovFormatter.config.report_with_single_file = true
SimpleCov.start 'rails' do
  if ENV['CI']
    formatter SimpleCov::Formatter::LcovFormatter
  else
    formatter SimpleCov::Formatter::MultiFormatter.new([
      SimpleCov::Formatter::SimpleFormatter,
      SimpleCov::Formatter::HTMLFormatter
    ])
  end

  track_files "lib/**/*.rb"
  add_filter "/lib/generators/updateable_views_inheritance/templates/create_updateable_views_inheritance.rb"
  add_filter "/lib/updateable_views_inheritance/version.rb"
end

require File.expand_path("../dummy/config/environment.rb",  __FILE__)
require 'rails/test_help'
require 'updateable_views_inheritance'

begin
  if RUBY_VERSION > "2"
    require 'byebug'
  else
    require 'debugger'
  end
rescue LoadError
  # no debugger available
end

class ActiveSupport::TestCase #:nodoc:
  include ActiveRecord::TestFixtures
  self.fixture_path = "#{File.dirname(__FILE__)}/fixtures/"
  ActiveRecord::Migration.verbose = false
end
