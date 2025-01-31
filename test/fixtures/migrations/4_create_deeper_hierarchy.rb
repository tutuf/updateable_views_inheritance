class CreateDeeperHierarchy < ActiveRecord::Migration[4.2]
  def self.up
    create_child(:maglev_locomotives, :parent => :electric_locomotives)  do |t|
      t.column :magnetic_field, :integer
    end
  end

  def self.down
    drop_child :maglev_locomotives
  end
end
