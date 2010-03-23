class TemplateContent < ActiveRecord::Base
end
=begin
TODO: cleanup

class TemplateContent < ActiveRecord::Base
  include Zena::Use::Upload::UploadedFile

  include RubyLess::SafeClass
  safe_attribute  :tkpath, :skin_name, :mode, :klass
  safe_method     :ext => String, :format => String, :content_type => String, :filename => String
  #attr_public  :file ?

  attr_protected :tkpath
  belongs_to :node
  belongs_to :site
  before_validation :template_content_before_validation
  validate   :validate_template_content

  # extend  Zena::Acts::Multiversion
  # act_as_content

  def preload_version(v)
    # dummy called by Version
  end

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

  def size(format=nil)
    version.text.size
  end

  def filename
    version.node.filename
  end

  def content_type=(s)
    # ignore
  end

  # pre-load version
  def version=(v)
    @version = v
  end

  def file=(file)
    @new_file = file
    version.text = file.read
  end

  def file(mode=nil)
    @new_file ||= StringIO.new(version.text)
  end

  def version
    @version ||= node.version
  end

  def can_destroy?
    0 == self.class.count_by_sql("SELECT COUNT(*) FROM versions WHERE node_id = #{self[:node_id]}")
  end

  # Return true if the version would be edited by the attributes
  # TODO: DRY this (and other code) with DocumentContent.
  def would_edit?(new_attrs)
    new_attrs.each do |k,v|
      if k == 'file'
        return true if (v.respond_to?(:size) ? v.size : File.size(v.path)) != self.size
        same = v.read(24) == self.file.read(24) && v.read == self.file.read
        v.rewind
        self.file.rewind
        return true if !same
      elsif type = self.class.safe_method_type([k])
        return true if field_changed?(k, self.send(type[:method]), v)
      end
    end
    false
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
      if klass_changed? && klass
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
=end