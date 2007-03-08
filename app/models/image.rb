class Image < Document
  link :icon_for, :class_name=>'Node', :as=>'icon'
  class << self
    def accept_content_type?(content_type)
      ImageBuilder.image_content_type?(content_type)
    end
  end
  
  def crop=(crop)
    return if @file # we do not want to crop on file upload in case the crop params lie around in the user's form
    x, y, w, h = crop[:x].to_i, crop[:y].to_i, crop[:w].to_i, crop[:h].to_i
    if (x >= 0 && y >= 0 && w <= c_width && h <= c_height)
      return if x==0 && y==0 && w == c_width && h == c_height
      # crop image
      img = ImageBuilder.new(:file=>c_file)
      img.crop!(x, y, w, h)
      filename = c_filename
      content_type = c_content_type
      @file = Tempfile.new(c_filename)
      File.open(@file.path, "wb") { |f| f.syswrite(img.read) }
      
      (class << @file; self; end;).class_eval do
        alias local_path path if defined?(:path)
        define_method(:original_filename) { filename }
        define_method(:content_type) { content_type }
      end
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
