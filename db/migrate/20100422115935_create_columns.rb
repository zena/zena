class CreateColumns < ActiveRecord::Migration
  def self.up
    create_table :columns do |t|
      t.integer 'role_id'
      t.string 'name'
      # Property Type
      t.string 'ptype'
      t.timestamps
    end
  end

  def self.down
    drop_table :columns
  end
end
