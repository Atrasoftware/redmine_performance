class AddSecondIndexes < ActiveRecord::Migration

  def change
    add_index :projects, :parent_id

  end
end