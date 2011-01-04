class FixZazenImageTag < ActiveRecord::Migration
  def self.up
    unless $migrating_new_db
      # Change all zazen image tags from !34.pv! to !34_pv! for better consistency with 'modes'.
      {
        Version.table_name        => [:text, :summary],
        'dyn_attributes'          => [:value],
        ContactContent.table_name => [:address],
        Comment.table_name        => [:text],
        DataEntry.table_name      => [:text],
      }.each do |table_name, keys|
        select_all("SELECT id,#{keys.join(',')} FROM #{table_name}", "#{table_name} Load").each do |record|
          new_value = {}
          keys.each do |k|
            next unless record[k.to_s]
            value = record[k.to_s].gsub(/\!([^0-9]{0,2}[0-9]+)(\.([^\/\!]+)|)(\/[^\!]*|)\!/) do
              "!#{$1}#{$3 ? "_#{$3}" : ''}#{$4}!"
            end
            new_value[k] = value if value != record[k.to_s]
          end
          execute "UPDATE #{table_name} SET #{new_value.map{|k,v| "#{k} = #{quote(v)}"}.join(', ')} WHERE id = #{record['id']}" if new_value != {}
        end
      end
    end
  end

  def self.down
    # Change back all zazen image tags from !34_pv! to !34.pv!
    {
      Version.table_name        => [:text, :summary],
      'dyn_attributes'          => [:value],
      ContactContent.table_name => [:address],
      Comment.table_name        => [:text],
      DataEntry.table_name      => [:text],
    }.each do |table_name, keys|
      select_all("SELECT id,#{keys.join(',')} FROM #{table_name}", "#{table_name} Load").each do |record|
        new_value = {}
        keys.each do |k|
          next unless record[k.to_s]
          value = record[k.to_s].gsub(/\!([^0-9]{0,2}[0-9]+)(_([^\/\!]+)|)(\/[^\!]*|)\!/) do
            "!#{$1}#{$3 ? ".#{$3}" : ''}#{$4}!"
          end
          new_value[k] = value if value != record[k.to_s]
        end
        execute "UPDATE #{table_name} SET #{new_value.map{|k,v| "#{k} = #{quote(v)}"}.join(', ')} WHERE id = #{record['id']}" if new_value != {}
      end
    end
  end
end
