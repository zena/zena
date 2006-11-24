=begin rdoc
=== New Document
link://../img/zena_new_document.png

=end
class Document < Page
  validate_on_create :check_file
  before_validation :set_name
  
  def file=(file)
    @file = file
    set_redaction(:file, file)
  end
  
  def image?
    kind_of?(Image)
  end
  
  def img_tag(format=nil)
    version.img_tag(format)
  end
  
  def filesize
    version.filesize
  end
  
  def file
    version.file
  end
  
  def ext
    version.file.ext
  end
  
  def filename
    version.filename
  end
  
  private
  
  def check_file
    errors.add('file', 'cannot be empty') unless @file && @file.respond_to?(:content_type)
  end
  
  def set_name
    self.class.logger.info "SET_NAME"
    if self[:name] && self[:name] != ""
      base = self[:name]
    elsif @file
      base = @file.original_filename
    else
      errors.add('name', 'cannot be empty')
      return false
    end
    if base =~ /\./
      self[:name] = base.split('.')[0..-2].join('.')
      version.ext = base.split('.').last
    end
    return true
  end
  
  # This is a callback from acts_as_multiversioned
  def version_class
    DocVersion
  end
end