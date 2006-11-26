class CreateCaches < ActiveRecord::Migration
  def self.up
    create_table("caches", :force => true, :options => 'type=InnoDB DEFAULT CHARSET=utf8') do |t|
      t.column "updated_at", :datetime
      t.column "user_id", :integer
      t.column "group_ids", :string, :limit => 200
      t.column "context", :string, :limit => 200
      t.column "content", :text
    end
  end

  def self.down
    drop_table "pcaches"
  end
end
