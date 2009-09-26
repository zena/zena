class ReplaceIdByZip < ActiveRecord::Migration
  def self.up
    create_table(:zips, :id=>false, :options => Zena::Db.table_options) do |t|
      t.column :site_id, :integer
      t.column :zip, :integer
    end

    add_column :nodes, :zip, :integer
  end

  def self.down
    drop_table :zips
    remove_column :nodes, :zip
  end
end

# FIXME: use mysql sequence: UPDATE zip_counter SET zip=@zip:=zip+1 WHERE site_id = '#{site[:id]}'; select @zip;