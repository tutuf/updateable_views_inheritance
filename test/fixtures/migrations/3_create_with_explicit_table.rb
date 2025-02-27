class CreateWithExplicitTable < ActiveRecord::Migration[4.2]
  def up
    create_child(:electric_locomotives, :table => :raw_electric_locomotives, :parent => :locomotives)  do |t|
      t.decimal :electricity_consumption, :precision => 6, :scale => 2
    end
  end

  def self.down
    drop_child  :electric_locomotives
  end
end
