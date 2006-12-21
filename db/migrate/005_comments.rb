class Comments < ActiveRecord::Migration
  def self.up
    create_table("discussions", :force => true, :options => 'type=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci') do |t|
      t.column "created_at", :datetime
      t.column "updated_at", :datetime
      t.column "item_id", :integer
      t.column "inside", :boolean, :default=>false  # if true, the discussion will not appear when published but when proposed or redaction
      t.column "open", :boolean, :default=>true
      t.column "lang", :string, :limit => 10, :default => "", :null => false
    end
    
    create_table("comments", :force => true, :options => 'type=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci') do |t|
      t.column "created_at", :datetime
      t.column "updated_at", :datetime
      t.column "discussion_id", :integer
      t.column "reply_to", :integer
      t.column "user_id", :integer
      t.column "title", :string, :limit => 250, :default => "", :null => false
      t.column "text", :text, :default => "", :null => false
      t.column "author_name",:string, :limit => 300
    end
  end

  def self.down
    drop_table "comments"
    drop_table "discussions"
  end
end
