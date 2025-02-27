require File.join(File.dirname(__FILE__), 'test_helper')

class DeepHierarchyTest < ActiveSupport::TestCase
  def setup
    ActiveRecord::Migrator.new(:up, ActiveRecord::MigrationContext.new("#{__dir__}/fixtures/migrations").migrations, 8).migrate

    ActiveRecord::FixtureSet.reset_cache
    # order of fixtures is important for the test - last loaded should not be with max(id)
    %w(boats electric_trains rack_trains steam_trains cars maglev_trains bicycles).each do |f|
      ActiveRecord::FixtureSet.create_fixtures(File.dirname(__FILE__) + '/fixtures/', f)
    end
    @connection = ActiveRecord::Base.connection
  end

  def test_deeper_hierarchy
    assert_equal [["boats"], ["railed_vehicles", ["trains", ["steam_trains"], ["rack_trains"], ["electric_trains", ["maglev_trains"]]]], ["wheeled_vehicles", ["bicycles"], ["cars"]]].sort,
                  @connection.send(:get_view_hierarchy_for, :vehicles).sort
  end

  def test_leaves_relations
    hierarchy = @connection.send(:get_view_hierarchy_for, :vehicles)
    assert_equal %w(boats bicycles cars maglev_trains rack_trains steam_trains).sort,
                  @connection.send(:get_leaves_relations, hierarchy).sort
  end

  def test_view_columns
    assert_equal %w(id vehicle_type name number_of_wheels number_of_doors number_of_gears number_of_rails mast_number max_speed water_consumption coal_consumption electricity_consumption bidirectional narrow_gauge magnetic_field rail_system).sort,
      @connection.columns(:all_vehicles).collect{|c| c.name}.sort
  end

  def test_single_table_inheritance_deeper_hierarchy_records_number
    assert_equal Vehicle.count, @connection.select_value("SELECT count(*) FROM all_vehicles").to_i
    assert_equal SteamTrain.count, @connection.select_value("SELECT count(*) FROM all_vehicles WHERE vehicle_type='SteamTrain'").to_i
    assert_equal ElectricTrain.count - MaglevTrain.count, @connection.select_value("SELECT count(*) FROM all_vehicles WHERE vehicle_type='ElectricTrain'").to_i
    assert_equal RackTrain.count, @connection.select_value("SELECT count(*) FROM all_vehicles WHERE vehicle_type='RackTrain'").to_i
    assert_equal MaglevTrain.count, @connection.select_value("SELECT count(*) FROM all_vehicles WHERE vehicle_type='MaglevTrain'").to_i
    assert_equal Car.count, @connection.select_value("SELECT count(*) FROM all_vehicles WHERE vehicle_type='Car'").to_i
    assert_equal Bicycle.count, @connection.select_value("SELECT count(*) FROM all_vehicles WHERE vehicle_type='Bicycle'").to_i
    assert_equal Boat.count, @connection.select_value("SELECT count(*) FROM all_vehicles WHERE vehicle_type='Boat'").to_i
  end

  def test_single_table_inheritance_deeper_hierarchy_contents
    mag = MaglevTrain.first
    assert_equal [mag.id, mag.name, mag.number_of_rails, mag.max_speed, mag.magnetic_field, (sprintf("%.2f",mag.electricity_consumption))], (@connection.query("SELECT id, name, number_of_rails, max_speed, magnetic_field, electricity_consumption FROM all_vehicles WHERE id=#{mag.id}").first)
  end

  class OrderColumnsInAggregateView < ActiveRecord::Migration[4.2]
    def up
      rebuild_single_table_inheritance_view(:all_vehicles,:vehicles, %w(max_speed number_of_wheels id))
    end
  end

  def test_single_table_inheritance_view_order_view_columns
    OrderColumnsInAggregateView.new.up
    assert_equal %w(max_speed number_of_wheels id),
                 (@connection.query("SELECT attname
                                       FROM pg_class, pg_attribute
                                      WHERE pg_class.relname = 'all_vehicles'
                                            AND pg_class.oid = pg_attribute.attrelid
                                   ORDER BY attnum").flatten)[0..2]
  end
end
