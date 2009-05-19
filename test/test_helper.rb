plugin_test_dir = File.dirname(__FILE__)
$:.unshift(plugin_test_dir + '/../lib')

RAILS_ROOT = File.dirname(__FILE__)

require 'test/unit'
require 'rubygems'
require 'active_record'
require 'active_record/fixtures'

config = ActiveRecord::Base.configurations = YAML::load(IO.read(plugin_test_dir + '/database.yml'))
ActiveRecord::Base.logger = Logger.new(plugin_test_dir + "/debug.log")
ActiveRecord::Base.establish_connection(config[ENV['DB']] || config['postgresql'])

require File.join(plugin_test_dir, '/../init')

class ActiveSupport::TestCase #:nodoc:
  include ActiveRecord::TestFixtures
  self.fixture_path = "#{File.dirname(__FILE__)}/fixtures/"
  self.use_transactional_fixtures = true
  self.use_instantiated_fixtures  = false
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
