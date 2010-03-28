class ChangeSkinNameToId < ActiveRecord::Migration
  def self.up
    add_column :nodes, :skin_id, :integer
    add_column :template_indices, :skin_id, :integer
    Site.all.each do |site|
      puts "===== fixing skin_id for #{site.host}"
      Skin.all(:conditions => ['site_id = ?', site.id]).each do |skin|
        puts "===== set skin_id for Skin #{skin.name}"
        execute "UPDATE nodes SET skin_id = #{skin.id} WHERE skin = #{quote(skin.name)} AND site_id = #{site.id}"
        execute "UPDATE template_indices SET skin_id = #{skin.id} WHERE skin_name = #{quote(skin.name)} AND site_id = #{site.id}"
      end
    end
    remove_column :nodes, :skin
    remove_column :template_indices, :skin_name
  end

  def self.down
    add_column :nodes, :skin, :string
    add_column :template_indices, :skin_name, :string
    Site.all.each do |site|
      puts "===== reviert fix skin_id for #{site.host}"
      Skin.all(:conditions => ['site_id = ?', site.id]).each do |skin|
        puts "===== set skin to #{skin.name}"
        execute "UPDATE nodes SET skin = #{quote(skin.name)} WHERE skin_id = #{skin.id} AND site_id = #{site.id}"
        execute "UPDATE template_indices SET skin_name = #{quote(skin.name)} WHERE skin_id = #{skin.id} AND site_id = #{site.id}"
      end
    end
    remove_column :nodes, :skin_id
    remove_column :template_indices, :skin_id
  end
end
