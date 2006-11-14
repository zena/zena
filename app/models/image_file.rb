class ImageFile < DocFile
  
  def self.find_or_new(vid, format)
    f = self.find_by_version_id_and_format(vid,format)
    unless f
      # create new
      f = ImageFile.find_by_version_id(vid)
      if f
        f = f.transform(format)
      else
        raise ActiveRecord::RecordNotFound, "No FileInfo with version_id '#{vid}'"
      end
    end
    f
  end
  
  def file=(aFile)
    super
    @file = ImageBuilder.new(:file=>aFile)
    self[:width]  = @file.width
    self[:height] = @file.height
  end
  
  def read
    if File.exist?(filepath)
      File.read(filepath)
    elsif @file
      @file.read
    else
      raise IOError
    end
  end
  
  def img_tag
    "<img src='/data#{path}' width='#{width}' height='#{height}'" + (format ? " class='#{format}'" : "") + "/>"
  end
  
  def name
    path.split('/').last
  end
  
  def transform(format)
    f = self.clone
    f.do_transform(format)
  end

  def do_transform(fmt)
    @file = ImageBuilder.new(:width=>self[:width], :height=>self[:height], :path=>filepath)
    unless format = IMAGEBUILDER_FORMAT[fmt]
      fmt = 'pv'
      format = IMAGEBUILDER_FORMAT['pv']
    end
    @file.transform!(format)
    self[:format] = fmt
    self[:path]   = make_path
    self[:width]  = @file.width
    self[:height] = @file.height
    self[:size]   = nil
    self
  end

  private
  def make_path
    doc = version.item
    if self[:format] and self[:format] =~ /^[a-z0-9]{1,16}$/
      self[:path] = "/#{doc.ext}/#{version_id}/#{doc.doc_name}-#{format}.#{doc.ext}"
    else
      super
    end
  end
end