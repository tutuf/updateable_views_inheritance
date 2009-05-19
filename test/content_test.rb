require File.join(File.dirname(__FILE__), 'test_helper')

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



end
