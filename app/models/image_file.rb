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
    @img = ImageBuilder.new(:file=>aFile)
    self[:width]  = @img.width
    self[:height] = @img.height
  end
  
  def dummy?
    !( (version && File.exist?(filepath)) || (@img && !ImageBuilder.dummy?) )
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
      @img = ImageBuilder.new(:width=>self[:width], :height=>self[:height], :path=>filepath)
    elsif !@img
      return nil
    end
    unless format = IMAGEBUILDER_FORMAT[fmt]
      fmt = 'pv'
      format = IMAGEBUILDER_FORMAT['pv']
    end
    @img.transform!(format)
    self[:format] = fmt
    self[:path]   = nil
    self[:path]   = make_path if self[:version_id]
    self[:width]  = @img.width
    self[:height] = @img.height
    self[:size]   = nil
    self
  end
  
  def size
    unless self[:size] ||= super
      if @img && !@img.dummy?
        self[:size] = @img.read.size
      end
    end
    self[:size]
  end

  def filename
    doc = version.item
    if self[:format] and self[:format] =~ /^[a-z0-9]{1,16}$/
      "#{doc.name}-#{format}.#{ext}"
    else
      super
    end
  end
  
  def clone
    new_obj = super
    if @file
      new_obj.file = @file
    end
    new_obj
  end
  
  def read
    if self[:version_id] && !new_record? && File.exist?(filepath)
      File.read(filepath)
    elsif @img
      @img.read
    elsif self[:format] && self[:version_id] && file = ImageFile.find_by_version_id_and_format(self[:version_id], nil)
      # rebuild image
      @img = ImageBuilder.new(:width=>file[:width], :height=>file[:height], :path=>file.filepath)
      @img.transform!(self[:format])
      if @img.width != self[:width] || @img.height != self[:height] || self[:size].nil? || self[:size] != @img.read.size
        self[:height] = @img.height
        self[:width]  = @img.width
        save
      end
      @img.read
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
    if @img
      if self[:format] == nil
        # original file clear previous content
        files = ImageFile.find(:all, :conditions=>["version_id = ? AND id <> ?", self[:version_id], self[:id]])
        files.each do |file|
          file.destroy
        end
      end
      super
    end
  end
end