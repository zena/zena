class ChangeSizeOfContenTypeField < ActiveRecord::Migration
  def self.up
    change_column :document_contents, :content_type, :string, :limit => 40
  end

  def self.down
    change_column :document_contents, :content_type, :string, :limit => 20
  end
end
