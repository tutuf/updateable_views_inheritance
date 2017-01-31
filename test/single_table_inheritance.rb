require File.join(File.dirname(__FILE__), 'test_helper')

class SingleTableInheritanceAggregateViewTest < ActiveSupport::TestCase
  def setup
    ActiveRecord::Migrator.up(File.dirname(__FILE__) + '/fixtures/migrations/', 6)
    # order of fixtures is important for the test - last loaded should not be with max(id)
    %w(electric_locomotives maglev_locomotives steam_locomotives).each do |f|
      ActiveRecord::FixtureSet.create_fixtures(File.dirname(__FILE__) + '/fixtures/', f)
    end
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
    assert_equal 'one', @connection.query("SELECT number_of_engines FROM all_locomotives WHERE id=#{SteamLocomotive.first.id}").first.first
    assert_equal '2', @connection.query("SELECT number_of_engines FROM all_locomotives WHERE id=#{ElectricLocomotive.first.id}").first.first
  end

  def test_respond_to_missing_attributes
    Locomotive.table_name = :all_locomotives
    assert !MaglevLocomotive.new.respond_to?(:non_existing_attribute_in_the_hierarchy), "Active Record is gone haywire - responds to attributes that are never defined"
    assert !MaglevLocomotive.new.respond_to?(:coal_consumption), "Responds to an attribute not defined in the class' view but in the STI view"
  end
end
