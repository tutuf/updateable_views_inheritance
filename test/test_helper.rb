class Rails
  def self.root
    File.dirname(__FILE__)
  end
end

require 'test/unit'
require 'rubygems'
require 'active_record'
require 'active_record/fixtures'

begin
  require 'ruby-debug'
rescue LoadError
  # no debugger available
end


config = ActiveRecord::Base.configurations = YAML::load(IO.read(File.dirname(__FILE__) + '/database.yml'))
ActiveRecord::Base.logger = Logger.new(File.dirname(__FILE__) + "/debug.log")
ActiveRecord::Base.establish_connection(config[ENV['DB']] || config['postgresql'])

require 'updateable_views_inheritance'

class ActiveSupport::TestCase #:nodoc:
  include ActiveRecord::TestFixtures
  self.fixture_path = "#{File.dirname(__FILE__)}/fixtures/"
  ActiveRecord::Migration.verbose = false
end

class Locomotive < ActiveRecord::Base
  abstract_class = true;
end
class SteamLocomotive < Locomotive
  self.table_name =  'steam_locomotives'
end
class ElectricLocomotive < Locomotive
  self.table_name =  'electric_locomotives'
end
class MaglevLocomotive < ElectricLocomotive
  self.table_name =  'maglev_locomotives'
end
class RackLocomotive < Locomotive
  self.table_name =  'rack_locomotives'
end

class Vehicle < ActiveRecord::Base
  abstract_class = true;
  self.inheritance_column = :vehicle_type
end
class WheeledVehicle < Vehicle
  self.table_name =  'wheeled_vehicles'
end
class RailedVehicle < Vehicle
  self.table_name =  'railed_vehicles'
end
class Boat < Vehicle
  self.table_name =  'boats'
end
class Car < WheeledVehicle
  self.table_name =  'cars'
end
class Bicycle < WheeledVehicle
  self.table_name =  'bicycles'
end
class Train < RailedVehicle
  self.table_name =  'trains'
end
class SteamTrain < Train
  self.table_name =  'steam_trains'
end
class RackTrain < Train
  self.table_name =  'rack_trains'
end
class ElectricTrain < Train
  self.table_name =  'electric_trains'
end
class MaglevTrain < ElectricTrain
  self.table_name =  'maglev_trains'
end
