class CreateIformats < ActiveRecord::Migration
  def self.up
    add_column :sites, :formats_updated_at, :datetime

    create_table(:iformats, :options => 'type=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci') do |t|
      t.column :name, :string, :limit => 40
      t.column :site_id, :integer
      t.column :created_at, :datetime
      t.column :updated_at, :datetime
      t.column :size,  :integer
      t.column :gravity,  :integer
      t.column :width, :integer
      t.column :height, :integer
    end
  end

  def self.down
    drop_table :iformats
    remove_column :sites, :formats_updated_at
  end
end
