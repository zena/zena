class FixTemplateTitle < ActiveRecord::Migration
  def self.up
    TemplateContent.all.each do |content|
      if klass  = content[:klass]
        format = content[:format] == 'html' ? '' : "-#{content[:format]}"
        mode   = (!content[:mode].blank? || format != '') ? "-#{content[:mode]}" : ''
        name   = "#{klass}#{mode}#{format}"
        execute "UPDATE versions SET title = #{quote(name)} WHERE node_id = #{content.node_id}"
      end
    end
    execute "UPDATE versions SET title = (SELECT name FROM nodes WHERE id = versions.node_id) WHERE title = '' OR title IS NULL"
  end

  def self.down
  end
end
