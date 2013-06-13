class AddClassTableInheritance < ActiveRecord::Migration
  def self.up
    create_table(:uvi, :id => false) do |t|
      t.column :parent_relation, :string
      t.column :child_aggregate_view, :string
      t.column :child_relation, :string
    end

    execute "ALTER TABLE uvi ADD PRIMARY KEY (parent_relation, child_aggregate_view, child_relation)"
  end

  def self.down
    drop_table :uvi
  end
end
