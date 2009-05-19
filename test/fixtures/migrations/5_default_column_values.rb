class DefaultColumnValues < ActiveRecord::Migration
  def self.up
    create_child(:rack_locomotives, :parent => :locomotives) do |t|
      t.column :bidirectional, :boolean, :default => false
      t.column :narrow_gauge, :boolean, :default => true
      t.column :rail_system, :string, :default => 'Abt'
    end
  end
  
  def self.down
    drop_child  :rack_locomotives
  end
end