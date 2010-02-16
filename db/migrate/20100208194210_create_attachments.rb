class CreateAttachments < ActiveRecord::Migration
  def self.up
    add_column :versions, :attachment_id, :integer

    create_table :attachments do |t|
      t.string    :filename
      t.integer   :site_id
      t.integer   :user_id
      t.timestamps
    end
  end

  def self.down
    remove_column :versions, :attachment_id
    drop_table :attachments
  end
end
