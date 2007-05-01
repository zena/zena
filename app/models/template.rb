class Template < TextDocument
  validate :valid_section
  
  class << self
    def accept_content_type?(content_type)
      content_type =~ /text\/(html|xml)/
    end
  end
  
  def name=(str)
    if str =~ /^([A-Z][a-zA-Z]+)(_([a-zA-Z]+)|)(\.(\w+)|)\.html/
      # starts with a capital letter = master template
      version.content.klass  = $1
      version.content.mode   = $3
      version.content.format = $5 || 'html'
    else
      # FIXME: we do not even need a TemplateContent...
      version.content.klass  = nil
      version.content.mode   = nil
      version.content.format = nil
    end
    super
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
