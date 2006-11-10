class ImageVersion < DocVersion
  
  def data(format=nil)
    @files ||= {}
    unless @files[format]
      @files[format] = ImageInfo.find_or_new(file_ref, format)
      @files[format].save if status == Zena::Status[:pub] and @files[format].new_record?
    end
    @files[format]
  end
  
  def img_tag(format=nil)
    data(format).img_tag
  end
  
  def filesize(format=nil); data(format).size; end
    
  private
  def info_class
    ImageInfo
  end
end
