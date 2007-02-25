# A skin is a master template containing all sub templates and css to render a full site or sectioon
# of a site.
class Skin < Template
  # opts can be :mode and :klass
  def template_url_for_name(template_name, helper)
    if template_name == 'any'
      template = self
    else
      template = secure(Template) { Template.find(:conditions=>["parent_id = ? AND name = ?", self[:id], template_name])}
    end
    tmpl_name = "#{template_name}_#{visitor_lang}.rhtml"
    tmpl_dir = "/templates/compiled/#{self[:name]}"
    FileUtils::mkpath("#{RAILS_ROOT}/app/views#{tmpl_dir}")
    # render for the current lang
    res = ZafuParser.new(template.version.text, :helper=>helper).render
    File.open("#{RAILS_ROOT}/app/views#{tmpl_dir}/#{tmpl_name}", "wb") { |f| f.syswrite(res) }
    return "#{tmpl_dir}/#{tmpl_name}"
  rescue ActiveRecord::RecordNotFound
    nil
  end
end