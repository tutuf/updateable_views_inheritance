require_relative 'test_helper'

class UpdateableViewsInheritanceMigrationTest < ActiveSupport::TestCase
  # We use transactional fixtures - migration from the setup is rolled back by Rails on teardown
  def setup
    @connection = ActiveRecord::Base.connection
  end

  def test_create_child_default
    ActiveRecord::MigrationContext.new("#{__dir__}/fixtures/migrations").migrate(2)
    assert_equal %w(coal_consumption id max_speed name type water_consumption),
                 @connection.columns(:steam_locomotives).map{ |c| c.name }.sort
  end

  def test_create_child_explicit_table
    ActiveRecord::MigrationContext.new("#{__dir__}/fixtures/migrations").migrate(3)
    assert_equal %w(electricity_consumption id max_speed name type),
                 @connection.columns(:electric_locomotives).map{ |c| c.name }.sort
  end

  def test_drop_child
    ActiveRecord::MigrationContext.new("#{__dir__}/fixtures/migrations").migrate(3)
    ActiveRecord::MigrationContext.new("#{__dir__}/fixtures/migrations").migrate(2)
    assert_equal %w(steam_locomotives), @connection.views.sort
    assert_equal %w(ar_internal_metadata
                    locomotives
                    schema_migrations
                    steam_locomotives_data
                    updateable_views_inheritance), @connection.tables.sort
  end
end
