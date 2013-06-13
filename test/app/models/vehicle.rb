class Vehicle < ActiveRecord::Base
  self.inheritance_column = :vehicle_type
end