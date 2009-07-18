class DateInLinks < ActiveRecord::Migration
  def self.up
    add_column    :links, :date, :datetime
  end

  def self.down
    remove_column :links, :date
  end
end
