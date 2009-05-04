class SecondDeepHierarchy < ActiveRecord::Migration
  # Create tables and views for the following inheritance hierarchy:
  #
  #                               vehicles
  #       ____________________________|_______________________________
  #       |                           |                               |
  # wheeled_vehicles            railed_vehicles                     boats
  #   ____|_____                      |
  #   |         |                     |
  # bicycles  cars                  trains
  #                   ________________|________________
  #                   |               |               |
  #             steam_trains    rack_trains     electric_trains
  #                                                   |
  #                                               maglev_trains
  def self.up
  
    create_table :vehicles do |t|
      t.column :name, :string
      t.column :vehicle_type, :string
    end
    
    create_table(:wheeled_vehicles_data, :id => false ) do |t|
      t.column :vehicle_id, :integer
      t.column :number_of_wheels, :integer
    end
    
      create_table(:bicycles_data, :id => false ) do |t|
        t.column :vehicle_id, :integer
        t.column :number_of_gears, :integer
      end
    
      create_table(:cars_data, :id => false ) do |t|
        t.column :vehicle_id, :integer
        t.column :number_of_doors, :integer
      end
    
    create_table( :railed_vehicles_data, :id => false ) do |t|
      t.column :vehicle_id, :integer
      t.column :number_of_rails, :integer
    end
      create_table(:trains_data, :id => false ) do |t|
        t.column :vehicle_id, :integer
        t.column :max_speed, :integer
      end
    
        create_table(:steam_trains_data, :id => false ) do |t|
          t.column :vehicle_id, :integer
          t.column :water_consumption, :decimal, :precision => 6, :scale => 2
          t.column :coal_consumption,  :decimal, :precision => 6, :scale => 2
        end
        create_table(:rack_trains_data, :id => false ) do |t|
          t.column :vehicle_id, :integer
          t.column :bidirectional, :boolean, :default => false
          t.column :narrow_gauge, :boolean, :default => true
          t.column :rail_system, :string, :default => 'Abt'
        end
        create_table(:electric_trains_data, :id => false ) do |t|
          t.column :vehicle_id, :integer
          t.column :electricity_consumption, :decimal, :precision => 6, :scale => 2
        end
        
          create_table(:maglev_trains_data, :id => false ) do |t|
            t.column :vehicle_id, :integer
            t.column :magnetic_field, :integer
          end
    create_table(:boats_data, :id => false ) do |t|
      t.column :vehicle_id, :integer
      t.column :mast_number, :integer
    end
    
    execute <<-end_sql
      ALTER TABLE wheeled_vehicles_data ADD PRIMARY KEY (vehicle_id);
      ALTER TABLE wheeled_vehicles_data ADD FOREIGN KEY (vehicle_id) REFERENCES vehicles ON DELETE CASCADE ON UPDATE CASCADE;
      ALTER TABLE bicycles_data ADD PRIMARY KEY (vehicle_id);
      ALTER TABLE bicycles_data ADD FOREIGN KEY (vehicle_id) REFERENCES vehicles ON DELETE CASCADE ON UPDATE CASCADE;
      ALTER TABLE cars_data ADD PRIMARY KEY (vehicle_id);
      ALTER TABLE cars_data ADD FOREIGN KEY (vehicle_id) REFERENCES vehicles ON DELETE CASCADE ON UPDATE CASCADE;
      
      ALTER TABLE railed_vehicles_data ADD PRIMARY KEY (vehicle_id);
      ALTER TABLE railed_vehicles_data ADD FOREIGN KEY (vehicle_id) REFERENCES vehicles ON DELETE CASCADE ON UPDATE CASCADE;
      ALTER TABLE trains_data ADD PRIMARY KEY (vehicle_id);
      ALTER TABLE trains_data ADD FOREIGN KEY (vehicle_id) REFERENCES vehicles ON DELETE CASCADE ON UPDATE CASCADE;
      ALTER TABLE steam_trains_data ADD PRIMARY KEY (vehicle_id);
      ALTER TABLE steam_trains_data ADD FOREIGN KEY (vehicle_id) REFERENCES vehicles ON DELETE CASCADE ON UPDATE CASCADE;
      ALTER TABLE rack_trains_data ADD PRIMARY KEY (vehicle_id);
      ALTER TABLE rack_trains_data ADD FOREIGN KEY (vehicle_id) REFERENCES vehicles ON DELETE CASCADE ON UPDATE CASCADE;
      ALTER TABLE electric_trains_data ADD PRIMARY KEY (vehicle_id);
      ALTER TABLE electric_trains_data ADD FOREIGN KEY (vehicle_id) REFERENCES vehicles ON DELETE CASCADE ON UPDATE CASCADE;
      ALTER TABLE maglev_trains_data ADD PRIMARY KEY (vehicle_id);
      ALTER TABLE maglev_trains_data ADD FOREIGN KEY (vehicle_id) REFERENCES vehicles ON DELETE CASCADE ON UPDATE CASCADE;
      
      ALTER TABLE boats_data ADD PRIMARY KEY (vehicle_id);
      ALTER TABLE boats_data ADD FOREIGN KEY (vehicle_id) REFERENCES vehicles ON DELETE CASCADE ON UPDATE CASCADE;
    end_sql
    create_child_view :vehicles, :wheeled_vehicles
    create_child_view :wheeled_vehicles, :bicycles
    create_child_view :wheeled_vehicles, :cars
    create_child_view :vehicles, :railed_vehicles
    create_child_view :railed_vehicles, :trains
    create_child_view :trains, :steam_trains
    create_child_view :trains, :rack_trains
    create_child_view :trains, :electric_trains
    create_child_view :electric_trains, :maglev_trains
    create_child_view :vehicles, :boats
  end
  
  def self.down
    drop_view  :boats
    drop_table :boats_data
    execute "DELETE FROM class_table_inheritance WHERE child_relation = 'boats_data'"
    drop_view  :maglev_trains
    drop_table :maglev_trains_data
    execute "DELETE FROM class_table_inheritance WHERE child_relation = 'maglev_trains_data'"
    drop_view  :electric_trains
    drop_table :electric_trains_data
    execute "DELETE FROM class_table_inheritance WHERE child_relation = 'electric_trains_data'"
    drop_view  :steam_trains
    drop_table :steam_trains_data
    execute "DELETE FROM class_table_inheritance WHERE child_relation = 'steam_trains_data'"
    drop_view  :rack_trains
    drop_table :rack_trains_data
    execute "DELETE FROM class_table_inheritance WHERE child_relation = 'rack_trains_data'"
    drop_view  :trains
    drop_table :trains_data
    execute "DELETE FROM class_table_inheritance WHERE child_relation = 'trains_data'"
    drop_view  :railed_vehicles
    drop_table :railed_vehicles_data
    execute "DELETE FROM class_table_inheritance WHERE child_relation = 'railed_vehicles_data'"
    drop_view  :cars
    drop_table :cars_data
    execute "DELETE FROM class_table_inheritance WHERE child_relation = 'cars_data'"
    drop_view  :bicycles
    drop_table :bicycles_data
    execute "DELETE FROM class_table_inheritance WHERE child_relation = 'bicycles_data'"
    drop_view  :wheeled_vehicles
    drop_table :wheeled_vehicles_data
    execute "DELETE FROM class_table_inheritance WHERE child_relation = 'wheeled_vehicles_data'"
    drop_table :vehicles
  end
end