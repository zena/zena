class Template < TextDocument
  class << self
    def accept_content_type?(content_type)
      content_type == 'text/html'
    end
  end
  
  # TODO: test
  def sweep_cache
    super
    if self.kind_of?(Skin)
      tmpl = "#{name}/any"
    else
      tmpl = "#{parent(:secure=>false)[:name]}/#{name}"
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
  
  def prepare_before_validation
    super
    content = version.content
    content[:content_type] = 'text/html'
    content[:ext] = 'html'
  end
end
