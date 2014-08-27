require File.join(File.dirname(__FILE__), 'test_helper')

class UpdateableViewsInheritanceSchemaTest < ActiveSupport::TestCase
  def setup
    ActiveRecord::Migrator.up(File.dirname(__FILE__) + '/fixtures/migrations/', 5)
    @connection = ActiveRecord::Base.connection
  end

  def test_pk_and_sequence_for
    assert_equal ['id', 'public.locomotives_id_seq'], @connection.pk_and_sequence_for(:maglev_locomotives), "Could not get pk and sequence for child aggregate view"
  end

  def test_primary_key
    assert_equal 'id', @connection.primary_key(:maglev_locomotives), "Wrong or no primary key for child aggregate view"
  end


  def test_content_columns
    assert !SteamLocomotive.content_columns.include?("id")
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
      ActiveRecord::Fixtures.create_fixtures(File.dirname(__FILE__) + '/fixtures/', :electric_locomotives)
      ActiveRecord::Fixtures.create_fixtures(File.dirname(__FILE__) + '/fixtures/', :maglev_locomotives)
      ActiveRecord::Fixtures.create_fixtures(File.dirname(__FILE__) + '/fixtures/', :steam_locomotives)
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

  def test_table_exists
    #TODO: test table_exists? monkey patch
  end

  class CreateChildInSchema < ActiveRecord::Migration
    def self.up
      execute "CREATE SCHEMA interrail"
      create_child("interrail.steam_locomotives", :parent => :locomotives) do |t|
        t.decimal :interrail_water_consumption, :precision => 6, :scale => 2
        t.decimal :interrail_coal_consumption,  :precision => 6, :scale => 2
      end
    end
  end

  def test_create_child_in_schema
    CreateChildInSchema.up
    assert_equal %w(id interrail_coal_consumption interrail_water_consumption max_speed name type),
                 @connection.columns('interrail.steam_locomotives').map{ |c| c.name }.sort
  end
end