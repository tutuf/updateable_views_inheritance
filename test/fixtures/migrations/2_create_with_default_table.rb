class CreateWithDefaultTable < ActiveRecord::Migration
  def self.up
    create_table :locomotives do |t|
      t.column :name, :string
      t.column :max_speed, :integer
      t.column :type, :string
    end
    
    create_table( :steam_locomotives_data, :id => false ) do |t|
      t.column :locomotive_id, :integer
      t.column :water_consumption, :decimal, :precision => 6, :scale => 2
      t.column :coal_consumption,  :decimal, :precision => 6, :scale => 2
    end
    execute "ALTER TABLE steam_locomotives_data ADD PRIMARY KEY (locomotive_id)"
    execute "ALTER TABLE steam_locomotives_data ADD FOREIGN KEY (locomotive_id) REFERENCES locomotives ON DELETE CASCADE ON UPDATE CASCADE"
    create_child_view :locomotives, :steam_locomotives
  end
  
  def self.down
    drop_view  :steam_locomotives
    drop_table :steam_locomotives_data
    execute "DELETE FROM class_table_inheritance WHERE child_relation = 'steam_locomotives_data'"
    drop_table :locomotives
  end
end