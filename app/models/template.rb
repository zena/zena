=begin rdoc
Definitions:

* master template: used to render a node. It is used depending on it's 'klass' filter.
* helper template: included into another template.

Render ---> Master template --include--> helper template --include--> ...

For master templates, the name is build from the different filters (klass, mode, format):

Klass-mode-format. Examples: Node-index, Node--xml, Project-info. Note how the format is omitted when it is 'html'.

Other templates have a name built from the given name, just like any other node.

=end
class Template < TextDocument
  validate :valid_section
  
  class << self
    def accept_content_type?(content_type)
      content_type =~ /text\/(html|xml|x-zafu-script)/ 
    end
    
    def version_class
      TemplateVersion
    end
  end
  
  def name=(str)
    @new_name = str
  end
  
  private
  
    # Overwrite document behaviour.
    def document_before_validation
      content = version.content
      content[:ext] = 'zafu'
      content[:content_type] = "x-zafu-script"
      if @new_name && @new_name =~ /^([A-Z][a-zA-Z\*]+?)(-([a-zA-Z_\*]*(-([a-zA-Z_]+)|))|)\Z/
        # starts with a capital letter = master template
        content.klass  = $1
        content.mode   = $3 
        content.format = $5 || 'html'
      elsif @new_name
        self[:name] = @new_name.nameForUrl
        content.klass  = nil
        content.mode   = nil
        content.format = nil
      end
      
      content.mode = content.mode.nameForUrl if content.mode
      
      if content.klass
        # update name
        format = content.format == 'html' ? '' : "-#{content.format}"
        mode   = (content.mode || format != '') ? "-#{content.mode}" : '' 
        self[:name] = "#{content.klass}#{mode}#{format}"
      end
    end
    
    def valid_section
      errors.add('parent_id', 'Invalid parent (section is not a Skin)') unless section.kind_of?(Skin)
    end
    
end
