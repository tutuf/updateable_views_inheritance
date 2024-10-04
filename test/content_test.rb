require_relative 'test_helper'

class UpdateableViewsInheritanceContentTest < ActiveSupport::TestCase
  def setup
    ActiveRecord::Migrator.up(File.dirname(__FILE__) + '/fixtures/migrations/', 5)
    ActiveRecord::FixtureSet.reset_cache
  end


  def test_find
    ActiveRecord::FixtureSet.create_fixtures(File.dirname(__FILE__) + '/fixtures/', :steam_locomotives)
    locomotive =  Locomotive.find(1)
    assert locomotive.kind_of?(SteamLocomotive)
    assert_equal %w(coal_consumption id max_speed name type water_consumption),
                 locomotive.attributes.keys.sort, "Could not instantiate properly child"
  end

  def test_exec_query
    # order of fixtures is important for the test - last loaded should not be with max(id)
    ActiveRecord::FixtureSet.create_fixtures(File.dirname(__FILE__) + '/fixtures/', :electric_locomotives)
    ActiveRecord::FixtureSet.create_fixtures(File.dirname(__FILE__) + '/fixtures/', :steam_locomotives)

    res = ActiveRecord::Base.connection.exec_query(<<-SQL)
      INSERT INTO electric_locomotives (electricity_consumption, max_speed, name, type)
        VALUES (40, 120, 'BoBo', 'ElectricLocomotive') RETURNING id
    SQL
    assert !res.rows.empty?, 'No id returned on INSERT in database view'
    assert_equal 3, res.rows.first.first.to_i
  end

  def test_exec_query_with_prepared_statement
    # order of fixtures is important for the test - last loaded should not be with max(id)
    ActiveRecord::FixtureSet.create_fixtures(File.dirname(__FILE__) + '/fixtures/', :electric_locomotives)
    ActiveRecord::FixtureSet.create_fixtures(File.dirname(__FILE__) + '/fixtures/', :steam_locomotives)

    binds = [[ElectricLocomotive.columns.find { |c| c.name == 'electricity_consumption'}, 40],
             [ElectricLocomotive.columns.find { |c| c.name == 'max_speed'},              120],
             [ElectricLocomotive.columns.find { |c| c.name == 'name'},                'BoBo'],
             [ElectricLocomotive.columns.find { |c| c.name == 'type'},  'ElectricLocomotive']]
    res = ActiveRecord::Base.connection.exec_query(<<-SQL, 'Test prepared statement', binds)
      INSERT INTO electric_locomotives (electricity_consumption, max_speed, name, type) VALUES ($1, $2, $3, $4) RETURNING id
    SQL
    assert !res.rows.empty?, 'Empty result on INSERT in database view through a prepared statement'
    assert_equal 3, res.rows.first.first.to_i
  end

  def test_save_new
    electric_locomotive = ElectricLocomotive.new(:name=> 'BoBo', :max_speed => 40, :electricity_consumption => 12)
    assert electric_locomotive.save, "Couldn't save new"
    assert electric_locomotive.id, "No id of saved object"
  end

  def test_reset_sequence_after_loading_fixture
    # order of fixtures is important for the test - last loaded should not be with max(id)
    ActiveRecord::FixtureSet.create_fixtures(File.dirname(__FILE__) + '/fixtures/', :electric_locomotives)
    ActiveRecord::FixtureSet.create_fixtures(File.dirname(__FILE__) + '/fixtures/', :steam_locomotives)
    steam_locomotive = SteamLocomotive.new(:name => 'Mogul', :max_speed => 120, :water_consumption => 12.3, :coal_consumption => 54.6)
    assert steam_locomotive.save
    mogul = Locomotive.find(steam_locomotive.id)
    assert mogul.kind_of?(SteamLocomotive)
  end

  def test_update
    ActiveRecord::FixtureSet.create_fixtures(File.dirname(__FILE__) + '/fixtures/', :steam_locomotives)
    steam_locomotive = Locomotive.find(1)
    steam_locomotive.update_attributes( :name => 'Rocket')
    steam_locomotive.reload
    assert_equal 'Rocket', steam_locomotive.name
  end

  def test_delete_from_parent_relation
    ActiveRecord::FixtureSet.create_fixtures(File.dirname(__FILE__) + '/fixtures/', :steam_locomotives)
    num_locomotives = Locomotive.count
    num_steam_locomotives = SteamLocomotive.count
    Locomotive.find(1).destroy
    assert_equal num_locomotives - 1, Locomotive.count
    assert_equal num_steam_locomotives - 1, SteamLocomotive.count
  end

  def test_delete_from_child_relation
    ActiveRecord::FixtureSet.create_fixtures(File.dirname(__FILE__) + '/fixtures/', :steam_locomotives)
    num_locomotives = Locomotive.count
    num_steam_locomotives = SteamLocomotive.count
    SteamLocomotive.find(1).destroy
    assert_equal num_locomotives - 1, Locomotive.count
    assert_equal num_steam_locomotives - 1, SteamLocomotive.count
  end
end
