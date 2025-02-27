class SecondDeepHierarchy < ActiveRecord::Migration[4.2]
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
  def up
    create_table :vehicles do |t|
      t.column :name, :string
      t.column :vehicle_type, :string
    end

    create_child(:wheeled_vehicles, :parent => :vehicles) do |t|
      t.column :number_of_wheels, :integer
    end

    create_child(:bicycles, :parent => :wheeled_vehicles) do |t|
      t.column :number_of_gears, :integer
    end

    create_child(:cars, :parent => :wheeled_vehicles) do |t|
      t.column :number_of_doors, :integer
    end

    create_child(:railed_vehicles, :parent => :vehicles) do |t|
      t.column :number_of_rails, :integer
    end

    create_child(:trains, :parent => :railed_vehicles) do |t|
      t.column :max_speed, :integer
    end

    create_child(:steam_trains, :parent => :trains) do |t|
      t.column :water_consumption, :decimal, :precision => 6, :scale => 2
      t.column :coal_consumption,  :decimal, :precision => 6, :scale => 2
    end

    create_child(:rack_trains, :parent => :trains) do |t|
      t.column :bidirectional, :boolean, :default => false
      t.column :narrow_gauge, :boolean, :default => true
      t.column :rail_system, :string, :default => 'Abt'
    end

    create_child(:electric_trains, :parent => :trains) do |t|
      t.column :electricity_consumption, :decimal, :precision => 6, :scale => 2
    end

    create_child(:maglev_trains, :parent => :electric_trains) do |t|
      t.column :magnetic_field, :integer
    end

    create_child(:boats, :parent => :vehicles) do |t|
      t.column :mast_number, :integer
    end
  end

  def self.down
    %w(boats maglev_trains electric_trains steam_trains rack_trains trains railed_vehicles cars bicycles wheeled_vehicles).each{|child| drop_child(child)}
    drop_table :vehicles
  end
end
