class TemplateContent < ActiveRecord::Base
  act_as_content
  attr_public     :tkpath, :ext, :format, :content_type, :filename, :mode, :klass, :skin_name
  
  # FIXME: use attr_accessible !
  #safe_attribute  :file
  
  attr_protected :tkpath
  belongs_to :node
  belongs_to :site
  before_validation :template_content_before_validation
  validate   :validate_template_content
  
  def ext
    'zafu'
  end
  
  # We need this because 'format' is a Kernel method and we do not want it to be called instead of getting the attribute.
  def format
    self[:format]
  end
  
  def ext=(s)
    # ignore (needed for compatibility with DocumentContent)
  end
  
  def content_type
    "text/zafu"
  end
  
  def content_type=(s)
    # ignore
  end
  
  # pre-load version
  def version=(v)
    @version = v
  end
  
  def file=(file)
    version.text = file.read
  end
  
  def file(mode=nil)
    t = StringIO.new(version.text)
    t
  end
  
  def version
    @version ||= node.version
  end
  
  def can_destroy?
    0 == self.class.count_by_sql("SELECT COUNT(*) FROM versions WHERE node_id = #{self[:node_id]}")
  end
  
  private
    def template_content_before_validation
      self[:skin_name] = node.section.name
      self[:mode]  = nil if self[:mode ].blank?
      self[:klass] = nil if self[:klass].blank?
      unless self[:klass]
        # this template is not meant to be accessed directly (partial used for inclusion)
        self[:tkpath] = nil
        self[:mode]   = nil
        self[:format] = nil
      end
    end
  
    def validate_template_content
      if klass
        errors.add('format', "can't be blank") unless format
        # this is a master template (found when choosing the template for rendering)
        if klass = Node.get_class(self[:klass])
          self[:tkpath] = klass.kpath
        else
          errors.add('klass', 'invalid')
        end
      end
    end
end
