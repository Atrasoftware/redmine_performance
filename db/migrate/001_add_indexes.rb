class AddIndexes < ActiveRecord::Migration

  def change
    add_index :projects, :updated_on
    add_index :projects, :identifier
    add_index :projects, :status
    add_index :issues,   :project_id
    add_index :issues,   :is_private
    add_index :projects, :id
    add_index :projects, :is_public

  end
end