# A skin is a master template containing all sub templates and css to render a full site or sectioon
# of a site.
class Skin < Section
  before_save :need_skin_name_update
  after_save  :update_skin_name
  
  def template_url_for_name(template_name, helper)
    raise Exception.new('helper should not be nil!') unless (helper || ENV["RAILS_ENV"] == "test")
    if template_name == 'any'
      template = self
      zafu_url = "/#{self[:name]}/any"
    else
      template = secure(Template) { Template.find(:first, :conditions=>["parent_id = ? AND name = ?", self[:id], template_name])}
      zafu_url = "/#{self[:name]}/#{template_name}"
    end
    tmpl_name = "#{template_name}_#{visitor.lang}"
    tmpl_dir = "/templates/compiled/#{self[:name]}"
    FileUtils::mkpath("#{RAILS_ROOT}/app/views#{tmpl_dir}")
    # render for the current lang
    res = ZafuParser.new_with_url(zafu_url, :helper=>helper).render
    File.open("#{RAILS_ROOT}/app/views#{tmpl_dir}/#{tmpl_name}.rhtml", "wb") { |f| f.syswrite(res) }
    return "#{tmpl_dir}/#{tmpl_name}"
  rescue ActiveRecord::RecordNotFound
    nil
  end
  
  def template_for_path(path)
    asset_for_path(path, Template)
  end
  
  
  def asset_for_path(path, klass=Node)
    current = self
    if path == 'any'
      return current
    else  
      path = path.split('/')
      while path != []
        template_name = path.shift
        current = secure(klass) { klass.find(:first, :conditions=>["parent_id = ? AND name = ?", current[:id], template_name])}
      end
      current
    end
  rescue ActiveRecord::RecordNotFound
    nil
  end
  
  private
  
    def need_skin_name_update
      return if new_record?
      @need_skin_name_update = (self[:name] != old[:name])
    end
    
    def update_skin_name
      return unless @need_skin_name_update
      # FIXME: escape correctly against sql injection
      # FIXME: when moving a template or a page that is a parent of a template: we must sync skin_name after spread_project_and_section.
      Skin.connection.execute "UPDATE nodes,template_contents SET template_contents.skin_name = '#{name.gsub(/^\w_\./,'')}' WHERE nodes.id = template_contents.node_id AND nodes.section_id = '#{self[:id].to_i}' AND template_contents.site_id = '#{self[:site_id].to_i}'"
    end
end