# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

require File.expand_path("../dummy/config/environment.rb",  __FILE__)
require 'rails/test_help'
require 'updateable_views_inheritance'

begin
  require 'ruby-debug'
rescue LoadError
  # no debugger available
end

class ActiveSupport::TestCase #:nodoc:
  include ActiveRecord::TestFixtures
  self.fixture_path = "#{File.dirname(__FILE__)}/fixtures/"
  ActiveRecord::Migration.verbose = false
end
