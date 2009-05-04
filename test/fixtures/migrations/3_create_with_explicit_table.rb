class CreateWithExplicitTable < ActiveRecord::Migration
  def self.up
    create_table( :raw_electric_locomotives, :id => false )  do |t|
      t.column :locomotive_id, :integer
      t.column :electricity_consumption, :decimal, :precision => 6, :scale => 2
    end
    execute "ALTER TABLE raw_electric_locomotives ADD PRIMARY KEY (locomotive_id)"
    execute "ALTER TABLE raw_electric_locomotives ADD FOREIGN KEY (locomotive_id) REFERENCES locomotives ON DELETE CASCADE ON UPDATE CASCADE"
    create_child_view :locomotives, :electric_locomotives, :raw_electric_locomotives
  end
  
  def self.down
    drop_view  :electric_locomotives
    drop_table :raw_electric_locomotives
    execute "DELETE FROM class_table_inheritance WHERE child_relation = 'electric_locomotives_data'"
  end
end