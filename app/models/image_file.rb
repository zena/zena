class ImageFile < DocFile
  
  def self.find_or_create(vid, format=nil)
    format = nil if format == 'full'
    f = self.find_by_version_id_and_format(vid,format)
    unless f
      # create new
      f = ImageFile.find_by_version_id_and_format(vid,nil)
      if f
        f = f.transform(format)
        f.save
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
    "<img src='/data#{path}' width='#{width}' height='#{height}' class='#{format ? format : 'full'}'/>"
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
      # rebuild image
      @data = ImageBuilder.new(:width=>file[:width], :height=>file[:height], :path=>file.filepath)
      @data.transform!(self[:format])
      if @data.width != self[:width] || @data.height != self[:height] || self[:size].nil? || self[:size] != @data.read.size
        self[:height] = @data.height
        self[:width]  = @data.width
        save
      end
      @data.read
    else
      raise IOError, "File not found"
    end
  end
  
  # TODO: remove_image_file not tested yet
  def remove_image_file
    if self[:format] && self[:version_id]
      FileUtils::rm(filepath) if File.exist?(filepath)
    end
  end
  
  private
  
  def save_file
    if @data && self[:version_id]
      p = File.join(*filepath.split('/')[0..-2])
      unless File.exist?(p)
        FileUtils::mkpath(p)
      end
      File.open(filepath, "wb") { |f| f.syswrite(@data.read) }
      self[:size] = File.stat(filepath).size
    end
  end
  
end