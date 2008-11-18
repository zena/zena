class AddDynAttributes < ActiveRecord::Migration
  def self.up
    create_table('dyn_attributes', :options => 'type=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci') do |t|
      t.column 'owner_id', :integer
      t.column 'owner_table', :string
      t.column 'key', :string
      t.column 'value', :text
    end
    add_index 'dyn_attributes', 'owner_id'
    add_index 'dyn_attributes', 'owner_table'
  end

  def self.down
    remove_index 'dyn_attributes', 'owner_id'
    remove_index 'dyn_attributes', 'owner_table'
    drop_table 'dyn_attributes'
  end
end