class Template < TextDocument
  validate :valid_section
  
  class << self
    def accept_content_type?(content_type)
      content_type =~ /text\/(html|xml)/
    end
    
    def version_class
      TemplateVersion
    end
  end
  
  def name=(str)
    if str =~ /^([A-Z][a-zA-Z]+?)(_([a-zA-Z_]+)|)(\.(\w+)|)\.html\Z/
      # starts with a capital letter = master template
      version.content.klass  = $1
      version.content.mode   = $3
      version.content.format = $5 || 'html'
    elsif str =~ /^([A-Z][a-zA-Z]+?)(_([a-zA-Z_]+)|)(\.(\w+)|)\Z/
      # starts with a capital letter = master template
      version.content.klass  = $1
      version.content.mode   = $3
      version.content.format = $5 || 'html'
    else
      version.content.klass  = nil
      version.content.mode   = nil
      version.content.format = nil
    end
    if str =~ /(.+)\.(.*)/
      super($1)
    else
      super
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
    
end
