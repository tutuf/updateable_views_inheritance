class SecondSingleTableInheritanceView < ActiveRecord::Migration[4.2]
  def up
    rebuild_parent_and_children_views(:vehicles)
    create_single_table_inheritance_view(:all_vehicles,:vehicles)
  end

  def self.down
    drop_view(:all_vehicles)
  end
end
