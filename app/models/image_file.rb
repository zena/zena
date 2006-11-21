class ImageFile < DocFile
  
  def self.find_or_new(vid, format=nil)
    f = self.find_by_version_id_and_format(vid,format)
    unless f
      # create new
      f = ImageFile.find_by_version_id_and_format(vid,nil)
      if f
        f = f.transform(format)
      else
        raise ActiveRecord::RecordNotFound, "No ImageFile with version_id '#{vid}'"
      end
    end
    f
  end
  
  def file=(aFile)
    super
    @data = ImageBuilder.new(:file=>aFile)
    self[:width]  = @data.width
    self[:height] = @data.height
  end
  
  def dummy?
    (!version || !File.exist?(filepath)) && (!@data || ImageBuilder.dummy?)
  end
  
  def img_tag
    "<img src='/data#{path}' width='#{width}' height='#{height}'" + (format ? " class='#{format}'" : "") + "/>"
  end
  
  def transform(format)
    f = self.clone
    f.do_transform(format)
  end

  def do_transform(fmt)
    if self[:version_id]
      # saved and has filepath
      @data = ImageBuilder.new(:width=>self[:width], :height=>self[:height], :path=>filepath)
    elsif !@data
      return nil
    end
    unless format = IMAGEBUILDER_FORMAT[fmt]
      fmt = 'pv'
      format = IMAGEBUILDER_FORMAT['pv']
    end
    @data.transform!(format)
    self[:format] = fmt
    self[:path]   = nil
    self[:path]   = make_path if self[:version_id]
    self[:width]  = @data.width
    self[:height] = @data.height
    self[:size]   = nil
    self
  end
  
  def size
    unless self[:size] ||= super
      if @data && !@data.dummy?
        self[:size] = @data.read.size
      end
    end
    self[:size]
  end

  def filename
    doc = version.item
    if self[:format] and self[:format] =~ /^[a-z0-9]{1,16}$/
      "#{doc.doc_name}-#{format}.#{doc.ext}"
    else
      super
    end
  end
  
  def clone
    new_obj = super
    if @data
      new_obj.file = @data.file
    end
    new_obj
  end
  
  def read
    if self[:version_id] && !new_record? && File.exist?(filepath)
      File.read(filepath)
    elsif @data
      @data.read
    elsif self[:format] && self[:version_id] && file = ImageFile.find_by_version_id_and_format(self[:version_id], nil)
      @data = ImageBuilder.new(:width=>self[:width], :height=>self[:height], :path=>file.filepath)
      @data.transform!(self[:format])
      save_image_file if version.status > Zena::Status[:red]
      @data.read
    else
      raise IOError, "File not found"
    end
  end
  
  private
  def save_image_file
    if @data
      p = File.join(*filepath.split('/')[0..-2])
      unless File.exist?(p)
        FileUtils::mkpath(p)
      end
      File.open(filepath, "wb") { |f| f.syswrite(@data.read) }
      self[:size] = File.stat(filepath).size
    end
  end
  
  def save_file
    if @data && self[:format] == nil
      # save original file on record creation. Only save transformed images on 'read'. This makes the 'read' operation stronger as we can clean the files and it will render again on demand.
      save_image_file
    end
  end
  
end