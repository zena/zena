class ReplaceIdByZip < ActiveRecord::Migration
  def self.up
    create_table(:zip_counter, :id=>false, :options => 'type=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci') do |t|
      t.column :site_id, :integer
      t.column :zip, :integer
    end
    
    add_column :nodes, :zip, :integer
  end

  def self.down
    drop_table :zip_counter
    remove_column :nodes, :zip
  end
end

# FIXME: use mysql sequence: UPDATE zip_counter SET zip=@zip:=zip+1 WHERE site_id = '#{site[:id]}'; select @zip;