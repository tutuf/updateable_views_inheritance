class AddUpdateableViewsInheritance < ActiveRecord::Migration[4.2]
  def self.up
    create_table(:updateable_views_inheritance, :id => false) do |t|
      t.column :parent_relation, :string
      t.column :child_aggregate_view, :string
      t.column :child_relation, :string
    end

    execute "ALTER TABLE updateable_views_inheritance ADD PRIMARY KEY (parent_relation, child_aggregate_view, child_relation)"
  end

  def self.down
    drop_table :updateable_views_inheritance
  end
end
