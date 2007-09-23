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
  
  def attributes=(new_attributes)
    attributes = new_attributes.stringify_keys
    ['c_klass','c_mode','c_format'].each do |sym|
      attributes.delete(sym) if attributes[sym] == ''
    end
    content    = version.content
    new_name   = attributes['name'] || (new_record? ? attributes['v_title'] : nil) # only set name from version title on creation
    if new_name =~ /^([A-Z][a-zA-Z\*]+?)(-(([a-zA-Z_\*]*)(-([a-zA-Z_]+)|))|)(\.|\Z)/
      attributes['c_klass' ] ||= $1
      attributes['c_mode'  ] ||= $4
      attributes['c_format'] ||= ($6 || 'html')
    elsif new_name && !attributes['c_klass']
      # name set but it is not a master template name
      attributes['c_klass']  = nil
    end
    super(attributes)
  end
  
  private
  
    # Overwrite document behaviour.
    def document_before_validation
      content = version.content
      
      content.mode = content.mode.url_name if content.mode
      
      if content.klass
        # update name
        content.format = 'html' if content.format.blank?
        format = content.format == 'html' ? '' : "-#{content.format}"
        mode   = (content.mode || format != '') ? "-#{content.mode}" : '' 
        self[:name] = "#{content.klass}#{mode}#{format}"
      end
    end
    
    def valid_section
      errors.add('parent_id', 'Invalid parent (section is not a Skin)') unless section.kind_of?(Skin)
    end
    
end
