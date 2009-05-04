require File.join(File.dirname(__FILE__), 'test_helper')

class ActiveRecord::Migration
  class << self
    attr_accessor :message_count
    def puts(text="")
      self.message_count ||= 0
      self.message_count += 1
    end
  end
end

class Locomotive < ActiveRecord::Base
  abstract_class = true;
end
class SteamLocomotive < Locomotive
  set_table_name 'steam_locomotives'
end
class ElectricLocomotive < Locomotive
  set_table_name 'electric_locomotives'
end
class MaglevLocomotive < ElectricLocomotive
  set_table_name 'maglev_locomotives'
end
class RackLocomotive < Locomotive
  set_table_name 'rack_locomotives'
end

class Vehicle < ActiveRecord::Base
  abstract_class = true;
  set_inheritance_column :vehicle_type
end
class WheeledVehicle < Vehicle
  set_table_name 'wheeled_vehicles'
end
class RailedVehicle < Vehicle
  set_table_name 'railed_vehicles'
end
class Boat < Vehicle
  set_table_name 'boats'
end
class Car < WheeledVehicle
  set_table_name 'cars'
end
class Bicycle < WheeledVehicle
  set_table_name 'bicycles'
end
class Train < RailedVehicle
  set_table_name 'trains'
end
class SteamTrain < Train
  set_table_name 'steam_trains'
end
class RackTrain < Train
  set_table_name 'rack_trains'
end
class ElectricTrain < Train
  set_table_name 'electric_trains'
end
class MaglevTrain < ElectricTrain
  set_table_name 'maglev_trains'
end

# migrations
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
end


# schema
class ClassTableInheritanceSchemaTest < ActiveSupport::TestCase  
  def setup
    ActiveRecord::Migrator.up(File.dirname(__FILE__) + '/fixtures/migrations/', 5)
    @connection = ActiveRecord::Base.connection
  end
  
  def test_pk_and_sequence_for
    assert_equal ['id', 'public.locomotives_id_seq'], @connection.pk_and_sequence_for(:maglev_locomotives), "Could not get pk and sequence for child aggregate view"
  end
  
  def test_views
    assert_equal ["electric_locomotives", "maglev_locomotives", "rack_locomotives", "steam_locomotives"], 
                 @connection.views.sort
  end
  
  class ParentTableWithOnlyOneColumn < ActiveRecord::Migration
    def self.up
      create_table(:parent_pk_only){}
      create_table :child_data do |t|
        t.column :name, :string
      end
      create_child_view :parent_pk_only, :child
    end
  end
  
  def test_parent_table_with_only_one_column
    ParentTableWithOnlyOneColumn.up
    assert @connection.views.include?('child')
    assert_equal %w(id name), @connection.columns(:child).map{|c| c.name}.sort
  end
  
  class ChildTableWithOnlyOneColumn < ActiveRecord::Migration
    def self.up
      create_table :parent do |t|
        t.column :name, :string
      end
      create_table(:child_pk_only_data){}
      create_child_view :parent, :child_pk_only
    end
  end
  
  def test_child_table_with_only_one_column
    ChildTableWithOnlyOneColumn.up
    assert @connection.views.include?('child_pk_only'), "Could not create child view when child table has only one column"
    assert_equal %w(id name), @connection.columns(:child_pk_only).map{|c| c.name}.sort
  end
  
  def test_serial_pk_has_default_in_view
    assert_equal %q|nextval('locomotives_id_seq'::regclass)|,
                 @connection.query(<<-end_sql, 'Serial PK has default in view')[0][0]
                   SELECT pg_catalog.pg_get_expr(d.adbin, d.adrelid) as constraint
                     FROM pg_catalog.pg_attrdef d, pg_catalog.pg_attribute a, pg_catalog.pg_class c
                    WHERE d.adrelid = a.attrelid 
                      AND d.adnum = a.attnum 
                      AND a.atthasdef 
                      AND c.relname = 'maglev_locomotives' 
                      AND a.attrelid = c.oid
                      AND a.attname = 'id'
                      AND a.attnum > 0 AND NOT a.attisdropped
                 end_sql
  end

  def test_default_value_string_of_view_column
    RackLocomotive.reset_column_information
    assert_equal 'Abt', RackLocomotive.new.rail_system
  end
  
  def test_default_value_boolean_of_view_column
    assert !RackLocomotive.new.bidirectional
    assert RackLocomotive.new.narrow_gauge
  end
    
  class ChangeDefaultValueOfColumn < ActiveRecord::Migration
    def self.up
      remove_parent_and_children_views(:rack_locomotives)
      change_column_default(:rack_locomotives_data, :rail_system, 'Marsh')
      rebuild_parent_and_children_views(:rack_locomotives)
    end
  end
  
  def test_change_default_value_of_column
    ChangeDefaultValueOfColumn.up
    RackLocomotive.reset_column_information
    assert_equal 'Marsh', RackLocomotive.new.rail_system
  end
  
  class RemoveChildrenViews < ActiveRecord::Migration
    def self.up
      remove_parent_and_children_views(:locomotives)
    end
  end
    
  def test_remove_parent_and_children_views
    RemoveChildrenViews.up
    assert @connection.views.empty?
  end
    
  class RemoveColumnInParentTable < ActiveRecord::Migration
    def self.up
      remove_parent_and_children_views(:locomotives)
      remove_column(:locomotives, :max_speed)
      rebuild_parent_and_children_views(:locomotives)
    end
  end
  
  def test_remove_column_parent_table
    RemoveColumnInParentTable.up
    assert_equal %w(coal_consumption id name type water_consumption),
                 @connection.columns(:steam_locomotives).map{ |c| c.name }.sort
    assert_equal %w(electricity_consumption id magnetic_field name type),
                 @connection.columns(:maglev_locomotives).map{ |c| c.name }.sort
  end
  
  class RenameColumnInParentTable < ActiveRecord::Migration
    def self.up
      Fixtures.create_fixtures(File.dirname(__FILE__) + '/fixtures/', :electric_locomotives)
      Fixtures.create_fixtures(File.dirname(__FILE__) + '/fixtures/', :maglev_locomotives)
      Fixtures.create_fixtures(File.dirname(__FILE__) + '/fixtures/', :steam_locomotives)
      remove_parent_and_children_views(:locomotives)
      rename_column(:locomotives, :max_speed, :maximal_speed)
      rebuild_parent_and_children_views(:locomotives)

    end
  end

  def test_rename_column_parent_table
    RenameColumnInParentTable.up
    assert_equal %w(coal_consumption id maximal_speed name type water_consumption),
                 @connection.columns(:steam_locomotives).map{ |c| c.name }.sort
    assert_equal %w(electricity_consumption id magnetic_field maximal_speed name type),
                 @connection.columns(:maglev_locomotives).map{ |c| c.name }.sort
    
  end
  
  class AddColumnToParentTable < ActiveRecord::Migration
    def self.up
      add_column(:raw_electric_locomotives, :number_of_engines, :integer)
      rebuild_parent_and_children_views(:electric_locomotives)
    end
  end
  
  def test_add_column_to_parent_table
    AddColumnToParentTable.up
    assert_equal %w(electricity_consumption id max_speed name number_of_engines type),
                 @connection.columns(:electric_locomotives).map{ |c| c.name }.sort
    assert_equal %w(electricity_consumption id magnetic_field max_speed name number_of_engines type),
                 @connection.columns(:maglev_locomotives).map{ |c| c.name }.sort
    
  end
  
  class ChangeChildRelationView < ActiveRecord::Migration
    def self.up
      remove_parent_and_children_views(:electric_locomotives)
      rename_column(:raw_electric_locomotives, :electricity_consumption, :electric_consumption)
      rebuild_parent_and_children_views(:electric_locomotives)
    end
  end
  
  def test_change_child_relation_view
    ChangeChildRelationView.up
    assert_equal %w(electric_consumption id max_speed name type),
                 @connection.columns(:electric_locomotives).map{ |c| c.name }.sort
  end
end

# Originally, fixtures are loaded in transactions. For content test commiting if this transaction will commit migration changes too
# and spoil subsequent tests
class Fixtures
  def self.create_fixtures(fixtures_directory, table_names, class_names = {})
    table_names = [table_names].flatten.map { |n| n.to_s }
    connection = block_given? ? yield : ActiveRecord::Base.connection
    ActiveRecord::Base.silence do
      fixtures_map = {}
      fixtures = table_names.map do |table_name|
        fixtures_map[table_name] = Fixtures.new(connection, File.split(table_name.to_s).last, class_names[table_name.to_sym], File.join(fixtures_directory, table_name.to_s))
      end               
      all_loaded_fixtures.merge! fixtures_map  

      fixtures.reverse.each { |fixture| fixture.delete_existing_fixtures }
      fixtures.each { |fixture| fixture.insert_fixtures }

      # Cap primary key sequences to max(pk).
      if connection.respond_to?(:reset_pk_sequence!)
        table_names.each do |table_name|
          connection.reset_pk_sequence!(table_name)
        end
      end

      return fixtures.size > 1 ? fixtures : fixtures.first
    end
  end
end

# CRUD and fixtures
class ClassTableInheritanceContentTest < ActiveSupport::TestCase
  def setup
    ActiveRecord::Migrator.up(File.dirname(__FILE__) + '/fixtures/migrations/', 5)
    # order of fixtures is important for the test - last loaded should not be with max(id)
    Fixtures.create_fixtures(File.dirname(__FILE__) + '/fixtures/', :electric_locomotives)
    Fixtures.create_fixtures(File.dirname(__FILE__) + '/fixtures/', :steam_locomotives)
  end
  
  def test_find
    locomotive =  Locomotive.find(1)
    assert locomotive.kind_of?(SteamLocomotive)
    assert_equal %w(coal_consumption id max_speed name type water_consumption), 
                 locomotive.attributes.keys.sort, "Could not instantiate properly child"
  end
  
  def test_save
    electric_locomotive = ElectricLocomotive.new(:name=> 'BoBo', :max_speed => 40, :electricity_consumption => 12)
    assert electric_locomotive.save
    bobo = Locomotive.find(electric_locomotive.id)
    assert bobo.kind_of?(ElectricLocomotive)
  end
  
  def test_reset_sequence_after_loading_fixture
    steam_locomotive = SteamLocomotive.new(:name => 'Mogul', :max_speed => 120, :water_consumption => 12.3, :coal_consumption => 54.6)
    assert steam_locomotive.save
    mogul = Locomotive.find(steam_locomotive.id)
    assert mogul.kind_of?(SteamLocomotive)
  end
  
  def test_update
    steam_locomotive = Locomotive.find(1)
    steam_locomotive.update_attributes( :name => 'Rocket')
    steam_locomotive.reload
    assert_equal 'Rocket', steam_locomotive.name
  end
  
  def test_delete_from_parent_relation
    num_locomotives = Locomotive.count
    num_steam_locomotives = SteamLocomotive.count
    Locomotive.find(1).destroy
    assert_equal num_locomotives - 1, Locomotive.count
    assert_equal num_steam_locomotives - 1, SteamLocomotive.count
  end
  
  def test_delete_from_child_relation
    num_locomotives = Locomotive.count
    num_steam_locomotives = SteamLocomotive.count
    SteamLocomotive.find(1).destroy
    assert_equal num_locomotives - 1, Locomotive.count
    assert_equal num_steam_locomotives - 1, SteamLocomotive.count
  end

# Single table ihertance aggregate view
class SingleTableInheritanceAggregateViewTest < ActiveSupport::TestCase  
  def setup
    ActiveRecord::Migrator.up(File.dirname(__FILE__) + '/fixtures/migrations/', 6)
    # order of fixtures is important for the test - last loaded should not be with max(id)
    Fixtures.create_fixtures(File.dirname(__FILE__) + '/fixtures/', :electric_locomotives)
    Fixtures.create_fixtures(File.dirname(__FILE__) + '/fixtures/', :maglev_locomotives)
    Fixtures.create_fixtures(File.dirname(__FILE__) + '/fixtures/', :steam_locomotives)
    @connection = ActiveRecord::Base.connection
  end
  
  def test_single_table_inheritance_view_schema
    @connection = ActiveRecord::Base.connection
    assert_equal %w(coal_consumption id max_speed name type water_consumption electricity_consumption bidirectional narrow_gauge magnetic_field rail_system).sort,
                 @connection.columns(:all_locomotives).map{ |c| c.name }.sort
  end
  
  def test_single_table_inheritance_records_number
    assert_equal Locomotive.count, @connection.query("SELECT count(*) FROM all_locomotives").first.first.to_i
    assert_equal SteamLocomotive.count, @connection.query("SELECT count(*) FROM all_locomotives WHERE type='SteamLocomotive'").first.first.to_i
    assert_equal ElectricLocomotive.count - MaglevLocomotive.count, @connection.query("SELECT count(*) FROM all_locomotives WHERE type='ElectricLocomotive'").first.first.to_i
    assert_equal RackLocomotive.count, @connection.query("SELECT count(*) FROM all_locomotives WHERE type='RackLocomotive'").first.first.to_i
    assert_equal MaglevLocomotive.count, @connection.query("SELECT count(*) FROM all_locomotives WHERE type='MaglevLocomotive'").first.first.to_i
  end
  
  def test_single_table_inheritance_save
    electric_locomotive = ElectricLocomotive.new(:name=> 'BoBo', :max_speed => 40, :electricity_consumption => 12)
    assert electric_locomotive.save
    assert_equal electric_locomotive.name, @connection.query("SELECT name FROm all_locomotives WHERE id=#{electric_locomotive.id}").first.first
  end
  
  class AddColumnToParentTable < ActiveRecord::Migration
    def self.up
      add_column(:raw_electric_locomotives, :number_of_engines, :integer)
      drop_view(:all_locomotives)
      rebuild_parent_and_children_views(:electric_locomotives)
      create_single_table_inheritance_view(:all_locomotives, :locomotives)
    end
  end
  
  def test_single_table_inheritance_view_add_column_to_parent_table
    AddColumnToParentTable.up
    assert_equal %w(coal_consumption id max_speed name type water_consumption electricity_consumption bidirectional narrow_gauge magnetic_field rail_system number_of_engines).sort,
                 @connection.columns(:all_locomotives).map{ |c| c.name }.sort
  end
  
  class RemoveColumnInParentTable < ActiveRecord::Migration
    def self.up
      drop_view(:all_locomotives)
      remove_parent_and_children_views(:locomotives)
      remove_column(:locomotives, :max_speed)
      rebuild_parent_and_children_views(:locomotives)
      create_single_table_inheritance_view(:all_locomotives,:locomotives)
    end
  end
  
  def test_single_table_inheritance_view_remove_column_parent_table
    RemoveColumnInParentTable.up
    assert_equal %w(coal_consumption id name type water_consumption electricity_consumption bidirectional narrow_gauge magnetic_field rail_system).sort,
                 @connection.columns(:all_locomotives).map{ |c| c.name }.sort
  end
  
  class RenameColumnInParentTable < ActiveRecord::Migration
    def self.up
      drop_view(:all_locomotives)
      remove_parent_and_children_views(:locomotives)
      rename_column(:locomotives, :max_speed, :maximal_speed)
      rebuild_parent_and_children_views(:locomotives)
      create_single_table_inheritance_view(:all_locomotives, :locomotives) 
    end
  end

  def test_single_table_inheritance_view_rename_column_parent_table
    RenameColumnInParentTable.up
    assert_equal %w(coal_consumption id maximal_speed name type water_consumption electricity_consumption bidirectional narrow_gauge magnetic_field rail_system).sort,
                 @connection.columns(:all_locomotives).map{ |c| c.name }.sort
  end
  
  class ChangeChildRelationView < ActiveRecord::Migration
    def self.up
      drop_view(:all_locomotives)
      remove_parent_and_children_views(:electric_locomotives)
      rename_column(:raw_electric_locomotives, :electricity_consumption, :electric_consumption)
      rebuild_parent_and_children_views(:electric_locomotives)
      create_single_table_inheritance_view(:all_locomotives, :locomotives)
    end
  end
  
  def test_single_table_inheritance_view_change_child_relation_view
    ChangeChildRelationView.up
    assert_equal %w(coal_consumption id max_speed name type water_consumption electric_consumption bidirectional narrow_gauge magnetic_field rail_system).sort,
                 @connection.columns(:all_locomotives).map{ |c| c.name }.sort
  end
  
  class ConflictColumns < ActiveRecord::Migration
    def self.up
      drop_view(:all_locomotives)
      add_column(:raw_electric_locomotives, :number_of_engines, :integer)
      add_column(:steam_locomotives_data, :number_of_engines, :string)
      rebuild_parent_and_children_views(:electric_locomotives)
      rebuild_parent_and_children_views(:steam_locomotives)
      create_single_table_inheritance_view(:all_locomotives, :locomotives)
    end
  end
  
  def test_single_table_inheritance_view_conflict_columns
    ConflictColumns.up
    assert_equal %w(coal_consumption id max_speed name type water_consumption electricity_consumption bidirectional narrow_gauge magnetic_field rail_system number_of_engines).sort,
                 @connection.columns(:all_locomotives).map{ |c| c.name }.sort
    assert_equal 'text', @connection.columns(:all_locomotives).detect{|c| c.name == "number_of_engines"}.sql_type
  end
  
  class ConflictColumnsWithValues < ActiveRecord::Migration
    def self.up
      add_column(:raw_electric_locomotives, :number_of_engines, :integer)
      add_column(:steam_locomotives_data, :number_of_engines, :string)
      execute("UPDATE raw_electric_locomotives SET number_of_engines = 2")
      execute("UPDATE steam_locomotives_data SET number_of_engines = 'one'")
      drop_view(:all_locomotives)
      rebuild_parent_and_children_views(:electric_locomotives)
      rebuild_parent_and_children_views(:steam_locomotives)
      create_single_table_inheritance_view(:all_locomotives, :locomotives)
    end
  end
  
  def test_single_table_inheritance_view_conflict_columns_with_values
    ConflictColumnsWithValues.up
    assert_equal %w(coal_consumption id max_speed name type water_consumption electricity_consumption bidirectional narrow_gauge magnetic_field rail_system number_of_engines).sort,
                 @connection.columns(:all_locomotives).map{ |c| c.name }.sort
    assert_equal 'text', @connection.columns(:all_locomotives).detect{|c| c.name == "number_of_engines"}.sql_type
    assert_equal 'one', @connection.query("SELECT number_of_engines FROM all_locomotives WHERE id=#{SteamLocomotive.find(:first).id}").first.first
    assert_equal '2', @connection.query("SELECT number_of_engines FROM all_locomotives WHERE id=#{ElectricLocomotive.find(:first).id}").first.first
  end
  
 
end

class DeeperHierarchyTest < ActiveSupport::TestCase  
  def setup
    ActiveRecord::Migrator.up(File.dirname(__FILE__) + '/fixtures/migrations/', 8)
    # order of fixtures is important for the test - last loaded should not be with max(id)
    Fixtures.create_fixtures(File.dirname(__FILE__) + '/fixtures/', :boats)
    Fixtures.create_fixtures(File.dirname(__FILE__) + '/fixtures/', :electric_trains)
    Fixtures.create_fixtures(File.dirname(__FILE__) + '/fixtures/', :rack_trains)
    Fixtures.create_fixtures(File.dirname(__FILE__) + '/fixtures/', :steam_trains)
    Fixtures.create_fixtures(File.dirname(__FILE__) + '/fixtures/', :cars)
    Fixtures.create_fixtures(File.dirname(__FILE__) + '/fixtures/', :maglev_trains)
    Fixtures.create_fixtures(File.dirname(__FILE__) + '/fixtures/', :bicycles)
    @connection = ActiveRecord::Base.connection
  end
  
  def test_deeper_hierarchy
    assert_equal [["boats"], ["railed_vehicles", ["trains", ["electric_trains", ["maglev_trains"]], ["rack_trains"], ["steam_trains"]]], ["wheeled_vehicles", ["bicycles"], ["cars"]]].sort,
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
    mag = MaglevTrain.find(:first)
    assert_equal [mag.id.to_s, mag.name, mag.number_of_rails.to_s, mag.max_speed.to_s, mag.magnetic_field.to_s, (sprintf("%.2f",mag.electricity_consumption))], (@connection.query("SELECT id, name, number_of_rails, max_speed, magnetic_field, electricity_consumption FROM all_vehicles WHERE id=#{mag.id}").first)
  end
  
  class OrderColumnsInAggregateView < ActiveRecord::Migration
    def self.up
      rebuild_single_table_inheritance_view(:all_vehicles,:vehicles, %w(max_speed number_of_wheels id))
    end
  end
  
  def test_single_table_inheritance_view_order_view_columns
    OrderColumnsInAggregateView.up
    assert_equal %w(max_speed number_of_wheels id),
                 (@connection.query("SELECT attname 
                                    FROM pg_class, pg_attribute WHERE 
                                    pg_class.relname = 'all_vehicles' AND 
                                    pg_class.oid = pg_attribute.attrelid").flatten)[0..2]
  end
end
end
