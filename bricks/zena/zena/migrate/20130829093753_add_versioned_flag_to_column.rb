class AddVersionedFlagToColumn < ActiveRecord::Migration
  def self.up
    add_column :columns, :versioned, :boolean
    execute "UPDATE columns SET versioned = 1"
  end

  def self.down
    remove_column :columns, :versioned
  end
end
