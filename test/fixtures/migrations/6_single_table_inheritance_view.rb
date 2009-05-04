class SingleTableInheritanceView < ActiveRecord::Migration
  def self.up
    rebuild_parent_and_children_views(:locomotives)
    create_single_table_inheritance_view(:all_locomotives,:locomotives)
  end

  def self.down
    drop_view(:all_locomotives)
  end
end