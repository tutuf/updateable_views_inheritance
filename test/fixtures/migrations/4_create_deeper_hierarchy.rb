class CreateDeeperHierarchy < ActiveRecord::Migration
  def self.up
    create_table( :maglev_locomotives_data, :id => false )  do |t|
      t.column :electric_locomotive_id, :integer
      t.column :magnetic_field, :integer
    end
    execute "ALTER TABLE maglev_locomotives_data ADD PRIMARY KEY (electric_locomotive_id)"
    execute "ALTER TABLE maglev_locomotives_data ADD FOREIGN KEY (electric_locomotive_id) REFERENCES raw_electric_locomotives ON DELETE CASCADE ON UPDATE CASCADE"
    create_child_view :electric_locomotives, :maglev_locomotives
    
  end
  def self.down
    drop_view :maglev_locomotives
    drop_table :maglev_locomotives_data
    execute "DELETE FROM class_table_inheritance WHERE child_relation = 'maglev_locomotives_data'"
  end
end
