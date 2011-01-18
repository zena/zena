class FixPublishFromIsNull < ActiveRecord::Migration
  def self.up
    execute "UPDATE #{Version.table_name} SET publish_from = updated_at WHERE status=50 AND publish_from IS NULL"
    execute "UPDATE #{Node.table_name} SET publish_from = updated_at WHERE max_status=50 AND publish_from IS NULL"
  end

  def self.down
  end
end
