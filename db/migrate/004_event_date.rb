class EventDate < ActiveRecord::Migration
  def self.up
    add_column :items, 'event_at', :datetime
  end

  def self.down
    remove_column :items, 'event_at'
  end
end
