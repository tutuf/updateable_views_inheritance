require_relative 'test_helper'

class InstantiationTest < ActiveSupport::TestCase
  def setup
    ActiveRecord::Migrator.up(File.dirname(__FILE__) + '/fixtures/migrations/', 7)
    # order of fixtures is important for the test - last loaded should not be with max(id)
    %w[steam_locomotives electric_locomotives maglev_locomotives bicycles].each do |f|
      ActiveRecord::FixtureSet.create_fixtures(File.dirname(__FILE__) + '/fixtures/', f)
    end
    @connection = ActiveRecord::Base.connection

    Locomotive.disable_inheritance_instantiation = true
    ElectricLocomotive.disable_inheritance_instantiation = false
  end

  def teardown
    Locomotive.disable_inheritance_instantiation = false
    ActiveRecord::FixtureSet.reset_cache
  end

  def test_setting_disable_inheritance_instantiation_does_not_load_child_columns
    assert_equal %w[id max_speed name type],
                 Locomotive.first.attributes.keys.sort
  end

  def test_switching_off_disable_inheritance_instantiation_loads_child_columns
    assert_equal %w[electricity_consumption id magnetic_field max_speed name type],
                 MaglevLocomotive.first.attributes.keys.sort
  end

  def test_disable_inheritance_instantiatioon_not_set_loads_child_attributes
    assert_equal %w[id name number_of_gears number_of_wheels vehicle_type],
                 Bicycle.first.attributes.keys.sort
  end
end
