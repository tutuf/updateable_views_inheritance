require_relative 'test_helper'

class SchemaTest < ActiveSupport::TestCase
  def setup
    ActiveRecord::Migrator.up(File.dirname(__FILE__) + '/fixtures/migrations/', 5)
    @connection = ActiveRecord::Base.connection
  end

  def test_pk_and_sequence_for
    pk, seq = @connection.pk_and_sequence_for(:maglev_locomotives)
    assert_equal 'id', pk
    assert_equal 'public.locomotives_id_seq', seq.to_s
  end

  class CreateChildInSchemaWithPublicParent < ActiveRecord::Migration
    def self.up
      execute "CREATE SCHEMA interrail"
      create_child('interrail.steam_locomotives', parent: 'locomotives') do |t|
        t.decimal :interrail_water_consumption, precision: 6, scale: 2
        t.decimal :interrail_coal_consumption,  precision: 6, scale: 2
      end
    end
  end

  def test_pk_and_sequence_for_child_and_parent_in_different_schemas
    CreateChildInSchemaWithPublicParent.up
    pk, seq = @connection.pk_and_sequence_for('interrail.steam_locomotives')
    assert_equal 'id', pk
    assert_equal 'public.locomotives_id_seq', seq.to_s
  end

  class CreateChildInSchemaWithParentInSchema < ActiveRecord::Migration
    def self.up
      execute "CREATE SCHEMA interrail"
      create_table 'interrail.locomotives' do |t|
        t.column :interrail_name, :string
        t.column :interrail_max_speed, :integer
        t.column :type, :string
      end
      create_child('interrail.steam_locomotives', parent: 'interrail.locomotives') do |t|
        t.decimal :interrail_water_consumption, precision: 6, scale: 2
        t.decimal :interrail_coal_consumption,  precision: 6, scale: 2
      end
    end
  end

  def test_pk_and_sequence_for_child_and_parent_in_same_nonpublic_schema
    CreateChildInSchemaWithParentInSchema.up
    pk, seq = @connection.pk_and_sequence_for('interrail.steam_locomotives')
    assert_equal 'id', pk
    assert_equal 'interrail.locomotives_id_seq', seq.to_s
  end

  def test_primary_key
    assert_equal 'id', @connection.primary_key(:maglev_locomotives), "Wrong or no primary key for child aggregate view"
  end

  def test_content_columns
    assert !SteamLocomotive.content_columns.map(&:name).include?("id")
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

    def self.down
      drop_child :child
      drop_table :parent_pk_only
    end
  end

  def test_parent_table_with_only_one_column
    ParentTableWithOnlyOneColumn.up
    assert @connection.views.include?('child')
    assert_equal %w(id name), @connection.columns(:child).map{|c| c.name}.sort
  ensure
    ParentTableWithOnlyOneColumn.down
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

  def test_does_not_preserve_not_null_on_views
    assert SteamLocomotive.columns.find { |c| c.name == 'water_consumption' }.null
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
      ActiveRecord::FixtureSet.create_fixtures(File.dirname(__FILE__) + '/fixtures/', :electric_locomotives)
      ActiveRecord::FixtureSet.create_fixtures(File.dirname(__FILE__) + '/fixtures/', :maglev_locomotives)
      ActiveRecord::FixtureSet.create_fixtures(File.dirname(__FILE__) + '/fixtures/', :steam_locomotives)
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

  class ChangeColumnInChildTable < ActiveRecord::Migration
    def self.up
      drop_view(:steam_locomotives)
      rename_column(:steam_locomotives_data, :coal_consumption, :fuel_consumption)
      create_child_view(:locomotives, :steam_locomotives)
    end
  end

  def test_change_column_in_child_table
    ChangeColumnInChildTable.up
    assert_equal %w(fuel_consumption id max_speed name type water_consumption),
                 @connection.columns(:steam_locomotives).map(&:name).sort
  end

  class CreateChildInSchema < ActiveRecord::Migration
    def self.up
      execute "CREATE SCHEMA interrail"
      create_table 'interrail.locomotives' do |t|
        t.column :interrail_name, :string
        t.column :interrail_max_speed, :integer
        t.column :type, :string
      end
      create_child('interrail.steam_locomotives', parent: 'interrail.locomotives') do |t|
        t.decimal :interrail_water_consumption, precision: 6, scale: 2
        t.decimal :interrail_coal_consumption,  precision: 6, scale: 2
      end
    end
  end

  def test_create_child_in_schema
    CreateChildInSchema.up
    assert_equal %w[id
                    interrail_coal_consumption
                    interrail_max_speed
                    interrail_name
                    interrail_water_consumption
                    type],
                 @connection.columns('interrail.steam_locomotives').map(&:name).sort
  end

  class ChangeTablesInTwoInheritanceChains < ActiveRecord::Migration
    def self.up
      add_column(:maglev_locomotives_data, :levitation_height, :integer)
      add_column(:bicycles_data, :wheel_size, :integer)
      rebuild_all_parent_and_children_views
    end
  end

  def test_rebuild_all_parent_and_children_views
    ActiveRecord::Migrator.up(File.dirname(__FILE__) + '/fixtures/migrations/', 7)
    @connection.execute "DROP VIEW all_locomotives" #FIXME: single table inheritance view should be rebuilt as well
    ChangeTablesInTwoInheritanceChains.up

    assert @connection.columns(:maglev_locomotives).map{ |c| c.name }.include?('levitation_height'),
           "Newly added column not present in view after rebuild for 1. hierarchy"
    assert @connection.columns(:bicycles).map{ |c| c.name }.include?('wheel_size'),
           "Newly added column not present in view after rebuild for 2. hierarchy"
  end

  class UseExistingTable < ActiveRecord::Migration
    def self.up
      create_table :tbl_diesel_locomotives do |t|
        t.belongs_to :locomotives
        t.integer :num_cylinders
      end
      create_child(:diesel_locomotives,
                   table: :tbl_diesel_locomotives,
                   parent: :locomotives,
                   skip_creating_child_table: true)
    end
  end

  def test_skip_creating_child_table
    UseExistingTable.up
    assert @connection.columns(:diesel_locomotives).map(&:name).include?("num_cylinders")
  end

  class ReservedSQLWords < ActiveRecord::Migration
    def self.up
      create_child(:table, parent: :locomotives) do |t|
        t.integer :column
      end
    end
    def self.down
      drop_child :table
    end
  end

  def test_reserved_words_in_tables_and_columns
    ReservedSQLWords.up
    assert @connection.columns(:table).map(&:name).include?("column")
  ensure
    ReservedSQLWords.down
  end

  class ChildTableIsActuallyView < ActiveRecord::Migration
    def self.up
      execute <<-SQL.squish
        CREATE VIEW punk_locomotives_data AS (
          SELECT steam_locomotives.id,
                 steam_locomotives.coal_consumption AS coal,
                 NULL AS electro
          FROM steam_locomotives
          UNION ALL
          SELECT electric_locomotives.id,
                 NULL AS coal,
                 electric_locomotives.electricity_consumption AS electro
          FROM electric_locomotives)
      SQL
      create_child(:punk_locomotives,
                   { parent: :locomotives,
                     child_table: :punk_locomotives_data,
                     child_table_pk: :id,
                     skip_creating_child_table: true })
    end
  end

  def test_child_table_is_view
    ChildTableIsActuallyView.up
    assert_equal @connection.columns(:punk_locomotives).map(&:name).sort,
                 %w(coal electro id max_speed name type)
  end
end
