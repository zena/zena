class AllowNullInTextFields < ActiveRecord::Migration
  FIELDS = ['versions.title', 'versions.summary', 'versions.text', 'versions.comment',
            'contact_contents.address']
  def self.up
    FIELDS.each do |f|
      table, field = f.split('.')
      change_column table, field, :text, :null => true
    end
  end

  def self.down
    FIELDS.each do |f|
      table, field = f.split('.')
      change_column table, field, :text, :default => '', :null => false
    end
  end
end
