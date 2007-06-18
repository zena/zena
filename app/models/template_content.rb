class TemplateContent < ActiveRecord::Base
  
  zafu_readable   :tkpath, :ext, :format, :content_type, :filename, :mode, :klass, :skin_name
  
  attr_protected :tkpath
  belongs_to :node
  belongs_to :site
  before_validation :template_content_before_validation
  validate   :validate_template_content
  
  def ext
    self[:format]
  end
  
  def format
    self[:format]
  end
  
  def content_type
    "text/#{format}"
  end
  
  def filename
    "#{node.name}.#{format}"
  end
  
  def content_type=(ctype)
    if ctype =~ /text\/(html|xml)/
      self[:format] = $2
    end
  end
  
  def file=(file)
    (@version || node.version).text = file.read
  end
  
  # Needed for compatibility with contents that are linked to versions.
  def version=(v)
    @version = v
    node = v.node
  end
  
  def can_destroy?
    0 == self.class.count_by_sql("SELECT COUNT(*) FROM versions WHERE node_id = #{self[:node_id]}")
  end
  
  private
    def template_content_before_validation
      self[:skin_name] = node.section.name
      self[:mode] = nil if self[:mode] == ''
      self[:klass] = nil if self[:klass] == ''
    end
  
    def validate_template_content
      errors.add('format', "can't be blank") unless format
      
      if self[:klass]
        # this is a master template (found when choosing the template for rendering)
        if klass = Node.get_class(self[:klass])
          self[:tkpath] = klass.kpath
        else
          errors.add('klass', 'invalid')
        end
      else
        # this template is not meant to be accessed directly (partial used for inclusion)
        self[:tkpath] = nil
      end
    end
end
