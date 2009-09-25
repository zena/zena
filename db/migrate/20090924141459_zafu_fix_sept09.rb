class ZafuFixSept09 < ActiveRecord::Migration
  def self.up
    # Update zafu from zena 0.13 to 0.14 (2009-09-24 changes)
    select_all("SELECT `id`, `text` FROM #{TemplateVersion.table_name}", "#{TemplateVersion.table_name} Load").each do |record|
      old_zafu = record['text']
      new_zafu = old_zafu.gsub(%r{<r:uses_calendar\s*/>}, '<r:uses_datebox/>')
      execute "UPDATE #{TemplateVersion.table_name} SET text = #{quote(new_zafu)} WHERE id = #{record['id']}" if new_zafu != old_zafu
    end
  end

  def self.down
    # Update zafu from zena 0.13 to 0.14 (2009-09-24 changes)
    select_all("SELECT `id`, `text` FROM #{TemplateVersion.table_name}", "#{TemplateVersion.table_name} Load").each do |record|
      old_zafu = record['text']
      new_zafu = old_zafu.gsub(%r{<r:uses_datebox\s*/>}, '<r:uses_calendar/>')
      execute "UPDATE #{TemplateVersion.table_name} SET text = #{quote(new_zafu)} WHERE id = #{record['id']}" if new_zafu != old_zafu
    end
  end
end
