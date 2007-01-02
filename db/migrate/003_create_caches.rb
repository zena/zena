class CreateCaches < ActiveRecord::Migration
  def self.up
    create_table("caches", :force => true, :options => 'type=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci') do |t|
      t.column "updated_at", :datetime
      t.column "visitor_id", :integer
      t.column "visitor_groups", :string, :limit => 200
      t.column "kpath", :string, :limit => 200
      t.column "context", :string, :limit => 200
      t.column "content", :text
    end
  end

  def self.down
    drop_table "caches"
  end
end
