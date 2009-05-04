class Vehicle < ActiveRecord::Base
  set_inheritance_column :vehicle_type
end