=begin rdoc
=== New Document
link://../img/zena_new_document.png

=end
class Document < Page
  before_save :check_name
  validate_on_create :check_file
  
  def file=(file)
    @file = file
    if new_record?
      self.name ||= file.original_filename
    end
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
  
  #def doc_name
  #  n = name.split('.')
  #  n.pop
  #  n.join('.')
  #end
  
  private
  
  def check_file
    errors.add('file', 'cannot be empty') unless @file && @file.respond_to?(:content_type)
  end
  
  # This is a callback from acts_as_multiversioned
  def version_class
    DocVersion
  end
  
  def check_name
    # get content_type
    if @file
      content_type = @file.content_type.chomp
    elsif !self.new_record?
      content_type = version.file.content_type
    else
      content_type = 'unknown'
    end
    # get extension
    str = name.split('.')
    if str.size > 1
      ext = str.pop
    else
      ext = nil
    end
    base = str.join('.')
    # is this extension valid ?
    extensions = TYPE_TO_EXT[content_type]
    if extensions
      ext = extensions.include?(ext) ? ext : extensions[0]
    else
      ext = "???"
    end
    self[:name] = "#{base}.#{ext}"
  end
end