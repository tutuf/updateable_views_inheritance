class CreateWithDefaultTable < ActiveRecord::Migration
  def self.up
    create_table :locomotives do |t|
      t.column :name, :string
      t.column :max_speed, :integer
      t.column :type, :string
    end
    
    create_child(:steam_locomotives, :parent => :locomotives) do |t|
      t.decimal :water_consumption, :precision => 6, :scale => 2
      t.decimal :coal_consumption,  :precision => 6, :scale => 2
    end
  end
  
  def self.down
    drop_child :steam_locomotives
    drop_table :locomotives
  end
end