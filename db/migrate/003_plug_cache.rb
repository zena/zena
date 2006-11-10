class PlugCache < ActiveRecord::Migration
  def self.up
    create_table("pcaches", :force => true, :options => 'type=InnoDB DEFAULT CHARSET=utf8') do |t|
      t.column "updated_at", :datetime
      t.column "visitor_id", :integer
      t.column "visitor_groups", :string, :limit => 40
      t.column "lang", :string, :limit => 10
      t.column "plug", :string, :limit => 20
      t.column "context", :string, :limit => 200
      t.column "content", :text
    end
  end

  def self.down
    drop_table "pcaches"
  end
end
