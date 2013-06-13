require File.join(File.dirname(__FILE__), 'test_helper')

class ClassTableInheritanceMigrationTest < ActiveSupport::TestCase
  # We use transactional fixtures - migration from the setup is rolled back by Rails on teardown
  def setup
    @connection = ActiveRecord::Base.connection
  end

  def test_create_child_default
    ActiveRecord::Migrator.up(File.dirname(__FILE__) + '/fixtures/migrations/', 2)
    assert_equal %w(coal_consumption id max_speed name type water_consumption),
                 @connection.columns(:steam_locomotives).map{ |c| c.name }.sort
  end

  def test_create_child_explicit_table
    ActiveRecord::Migrator.up(File.dirname(__FILE__) + '/fixtures/migrations/', 3)
    assert_equal %w(electricity_consumption id max_speed name type),
                 @connection.columns(:electric_locomotives).map{ |c| c.name }.sort
  end
  
  def test_drop_child
    ActiveRecord::Migrator.up(File.dirname(__FILE__) + '/fixtures/migrations/', 3)
    ActiveRecord::Migrator.down(File.dirname(__FILE__) + '/fixtures/migrations/', 2)
    assert_equal %w(steam_locomotives), @connection.views.sort
    assert_equal %w(uvi 
                    locomotives
                    schema_migrations
                    steam_locomotives_data), @connection.tables.sort
  end
end