class Template < TextDocument
  validate :valid_section
  
  class << self
    def accept_content_type?(content_type)
      content_type =~ /text\/(html|xml)/
    end
  end
  
  # Find the
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
  
    # Overwrite document behaviour.
    def document_before_validation
      content = version.content
      content[:format] ||= 'html'
    end
    
    def valid_section
      errors.add('parent_id', 'Invalid parent (section is not a Skin)') unless section.kind_of?(Skin)
    end
    
    def version_class
      TemplateVersion
    end
end
