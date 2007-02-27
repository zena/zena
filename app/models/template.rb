class Template < TextDocument
  before_validation :set_content_type
  # TODO: test
  def sweep_cache
    super
    if self.kind_of?(Skin)
      tmpl = "#{name}/any"
    else
      tmpl = "#{parent[:name]}/#{name}"
    end
    ZENA_ENV[:languages].each do |lang|
      filepath = File.join(RAILS_ROOT,'app', 'views', 'templates', 'compiled')
      filepath = "#{filepath}/#{tmpl}_#{lang}.rhtml"
      if File.exist?(filepath)
        File.delete(filepath)
      end
    end
  end
  private
  
  # TODO: test
  def set_content_type
    version.redaction_content.content_type = 'text/html'
    version.content.ext  = 'html'
    version.content.name = name
  end
end
