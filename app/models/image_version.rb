class ImageVersion < DocVersion
  
  def file(format=nil)
    @files ||= {}
    unless @files[format]
      img = ImageFile.find_or_new(file_ref, format)
      if !img.dummy? && status == Zena::Status[:pub] && img.new_record?
        img.save
      end
      @files[format] = img
    end
    @files[format]
  end
  
  def img_tag(format=nil)
    file(format).img_tag
  end
  
  def filesize(format=nil); file(format).size; end
    
  private
  def file_class
    ImageFile
  end
end
