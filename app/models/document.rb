=begin rdoc
=== New Document
link://../img/zena_new_document.png

=end
class Document < Page
  before_save :check_name
  
  def validate_on_create
    super
    errors.add('file', 'cannot be empty') unless @file && @file != ''
  end
  
  def file=(file)
    logger.info "Document: file= called"
    @file = file # we need this to check a file was uploaded
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
  
  def data
    version.data
  end
  
  def doc_name
    n = name.split('.')
    n.pop
    n.join('.')
  end
  
  private
  # This is a callback from acts_as_multiversioned
  def version_class
    DocVersion
  end
  
  def check_name
    str = name.split('.')
    if @file
      content_type = @file.content_type.chomp
    elsif @version
      content_type = @version.data.content_type
    else
      content_type = 'unknown'
    end
    if str.size > 1
      ext = str.last
      str.pop
    else
      ext = nil
    end
    base = str.join('.')
    extensions = TYPE_TO_EXT[content_type]
    if extensions
      ext = extensions.include?(ext) ? ext : extensions[0]
    else
      ext = "???"
    end
    self[:name] = "#{base}.#{ext}"
  end
end