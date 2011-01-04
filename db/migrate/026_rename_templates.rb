class RenameTemplates < ActiveRecord::Migration
  def self.up
    unless $migrating_new_db
      mode_change = [ ['search', '*search'],
        ['admin_layout', '*adminLayout'],
        ['index', '*index'],
        ['not_found', '*notFound'],
        ['popup_layout', '*popupLayout'],
        ['login', '*login']
      ]
      mode_translation = Hash[*mode_change.flatten]
      mode_change.each do |old_name, new_name|
        execute "UPDATE #{TemplateContent.table_name} SET mode = '#{new_name}' WHERE mode = '#{old_name}'"
      end
      Template.find(:all).each do |t|
        content = TemplateContent.find(:first, :conditions => "node_id = #{t[:id]}")
        if content.klass
          # update name
          content.format ||= 'html'
          format = content.format == 'html' ? '' : "-#{content.format}"
          mode   = (content.mode || format != '') ? "-#{content.mode}" : ''
          new_name = "#{content.klass}#{mode}#{format}"
          execute "UPDATE #{Node.table_name} SET name = #{quote(new_name)} WHERE id = #{t[:id]}"
        end
        Version.find_all_by_node_id(t[:id]).each do |v|
          text = v.text
          new_text = text.gsub(/template\s*=\s*("|')([^\1]+?)\1/) do
            sep, template_name = $1, $2
            if template_name =~ /\A(\w+)(_(.+)|)(\.(\w+)|)/
              base, mode, format = $1, $3, $5
              format = (format && format != 'html') ? "-#{format}" : ''
              if mode
                mode = mode_translation[mode] || mode
                template_name = "#{base}-#{mode}#{format}"
              else
                template_name = "#{base}#{format}"
              end
            end
            "template='#{template_name}'"
          end
          execute "UPDATE #{Version.table_name} SET text = #{quote(new_text)} WHERE id = #{v[:id]}"
        end
      end
    end
  end

  def self.down
  end
end
