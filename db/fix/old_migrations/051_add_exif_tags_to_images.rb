class AddExifTagsToImages < ActiveRecord::Migration
  def self.up
    add_column :document_contents, :exif_json, :text
  end

  def self.down
    remove_column :document_contents, :exif_json
  end
end
