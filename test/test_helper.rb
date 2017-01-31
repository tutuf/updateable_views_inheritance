# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

require File.expand_path("../dummy/config/environment.rb",  __FILE__)
require 'rails/test_help'
require 'updateable_views_inheritance'

# get full stack trace on errors
require "minitest/reporters"
Minitest::Reporters.use!

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
