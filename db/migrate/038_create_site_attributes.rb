class CreateSiteAttributes < ActiveRecord::Migration
  def self.up
    create_table('site_attributes', :options => 'type=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci') do |t|
      t.column 'owner_id', :integer
      t.column 'key', :string
      t.column 'value', :text
    end
    add_index 'site_attributes', 'owner_id'
  end

  def self.down
    remove_index 'site_attributes', 'owner_id'
    drop_table 'site_attributes'
  end
end
