class Vehicle < ActiveRecord::Base
  abstract_class = true
  self.inheritance_column = :vehicle_type
end
