class Image < Document
  class << self
    def accept_content_type?(content_type)
      ImageBuilder.image_content_type?(content_type)
    end
  end
  
  def file(format=nil)
    version.file(format)
  end
  
  def filesize(format=nil)
    version.filesize(format)
  end
  
  private
  # This is a callback from acts_as_multiversioned
  def version_class
    ImageVersion
  end
end
