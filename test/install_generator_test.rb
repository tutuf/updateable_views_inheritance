require File.join(File.dirname(__FILE__), 'test_helper')
require 'generators/updateable_views_inheritance/install_generator'

class InstallGeneratorTest < Rails::Generators::TestCase
  destination File.join(Rails.root, "tmp")
  setup :prepare_destination
  tests UpdateableViewsInheritance::Generators::InstallGenerator
  
  test "create migration" do
    run_generator
    assert_migration 'db/migrate/create_updateable_views_inheritance.rb'
  end
end