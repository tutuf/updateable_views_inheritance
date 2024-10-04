# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

# test coverage
require 'simplecov'

SimpleCov.start 'rails' do
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
