=begin rdoc
=== New Document
link://../img/zena_new_document.png

=end
class Document < Page
  before_validation :set_name
  
  def c_file=(file)
    @file = file
    redaction.content.file = file
  end
  
  def image?
    kind_of?(Image)
  end
  
  def img_tag(format=nil)
    version.content.img_tag(format)
  end
  
  private
  
  def set_name
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
      version.content.ext  = base.split('.').last
      version.content.name = self[:name]
    end
    return true
  end
  
  # This is a callback from acts_as_multiversioned
  def version_class
    DocumentVersion
  end
end