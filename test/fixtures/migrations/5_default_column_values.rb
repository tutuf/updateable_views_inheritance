class DefaultColumnValues < ActiveRecord::Migration
  def self.up
    create_table(:rack_locomotives_data, :id => false) do |t|
      t.column :locomotive_id, :integer
      t.column :bidirectional, :boolean, :default => false
      t.column :narrow_gauge, :boolean, :default => true
      t.column :rail_system, :string, :default => 'Abt'
    end
    execute "ALTER TABLE rack_locomotives_data ADD PRIMARY KEY (locomotive_id)"
    execute "ALTER TABLE rack_locomotives_data ADD FOREIGN KEY (locomotive_id) REFERENCES locomotives ON DELETE CASCADE ON UPDATE CASCADE"
    create_child_view :locomotives, :rack_locomotives
  end
  
  def self.down
    drop_view  :rack_locomotives
    drop_table :rack_locomotives_data
    execute "DELETE FROM class_table_inheritance WHERE child_relation = 'rack_locomotives_data'"
  end
end