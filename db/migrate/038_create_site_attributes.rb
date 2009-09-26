class CreateSiteAttributes < ActiveRecord::Migration
  def self.up
    create_table('site_attributes', :options => Zena::Db.table_options) do |t|
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
