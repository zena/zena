class ImageContent < DocumentContent
  
  # Crop the image using the 'crop' hash with the top left corner position (:x, :y) and the width and height (:width, :heigt). Example:
  #   @node.crop = {:x=>10, :y=>10, :width=>30, :height=>60}
  # Be carefull as this method changes the current file. So you should make a backup version before croping the image (the popup editor displays a warning).
  def crop=(crop)
    return if @file # we do not want to crop on file upload in case the crop params lie around in the user's form
    x, y, w, h = crop[:x].to_i, crop[:y].to_i, crop[:w].to_i, crop[:h].to_i

    # crop image
    img = ImageBuilder.new(:file=>file)
    img.crop!(x, y, w, h)
    file = Tempfile.new(filename)
    File.open(file.path, "wb") { |f| f.syswrite(img.read) }
    fname = filename
    ctype = content_type
    (class << file; self; end;).class_eval do
      alias local_path path if defined?(:path)
      define_method(:original_filename) { fname }
      define_method(:content_type) { ctype }
    end
    self.file = file
  end
  
  def file=(aFile)
    super
    return unless ImageBuilder.image_content_type?(aFile.content_type)
    remove_format_images if !new_record?
    img = image_for_format(nil)
    self[:width ] = img.width
    self[:height] = img.height
  end
  
  def img_tag(format=nil, opts={})
    format = verify_format(format) || 'std'
    options = {:class=>(format || 'full'), :id=>nil, :alt=>name}.merge(opts)
    if format == 'full'
      # full size (format = nil)
      "<img src='/data#{path}' width='#{self.width}' height='#{self.height}' alt='#{options[:alt]}' #{options[:id] ? "id='#{options[:id]}' " : ""}class='#{options[:class]}'/>"
    elsif self[:width] && self[:height]
      # build image tag
      img = image_for_format(format)
      "<img src='/data#{path(format)}' width='#{img.width}' height='#{img.height}' alt='#{options[:alt]}' #{options[:id] ? "id='#{options[:id]}' " : ""}class='#{options[:class]}'/>"
    else
      # cannot build if 'width' and 'height' are not set
      "<img src='/data#{path(format)}' alt='#{options[:alt]}' #{options[:id] ? "id='#{options[:id]}' " : ""}class='#{options[:class]}'/>"
    end
  end
  
  def size(format=nil)
    format = verify_format(format)
    if format == 'full'
      super
    elsif format
      if File.exist?(filepath(format)) || make_image(format)
        File.stat(filepath(format)).size
      else
        nil
      end
    else
      nil
    end
  end
  
  def width(format=nil)
    format = verify_format(format)
    if format == 'full'
      self[:width]
    elsif format
      if img = image_for_format(format)
        img.width
      else
        nil
      end
    else
      nil
    end
  end
  
  def height(format=nil)
    format = verify_format(format)
    if format == 'full'
      self[:height]
    elsif format
      if img = image_for_format(format)
        img.height
      else
        nil
      end
    else
      nil
    end
  end

  def filename(format=nil)
    format = verify_format(format)
    if format == 'full'
      super
    elsif format
      "#{name}-#{format}.#{ext}"
    else
      nil
    end
  end
  
  # Send a file with the data for the given format. It is the receiver's responsability to close the file.
  def file(format=nil)
    return nil if format == 'full' # We only send full data when asked with format is nil.
    format = verify_format(format)
    if format == 'full'
      if @file
        @file
      elsif File.exist?(filepath)
        File.new(filepath)
      else
        nil
      end
    elsif format
      if File.exist?(filepath(format)) || make_image(format)
        File.new(filepath(format))
      else
        nil
      end
    else
      nil
    end
  end
  
  # Used to remove specific formatted images when these images are cached in the public directory
  def remove_image(format)
    return false unless format = verify_format(format)
    FileUtils::rm(filepath(format)) if File.exist?(filepath(format))
  end
  
  # Removes all images created by ImageBuilder for this image_content. This is used when the file changes.
  def remove_format_images
    dir = File.dirname(filepath)
    if File.exist?(dir)
      Dir.foreach(dir) do |file|
        next if file =~ /^\./
        next if file == filename
        FileUtils::rm(File.join(dir,file))
      end
    end
    # Remove cached images from the public directory.
    # TODO: test
    FileUtils::rmtree(File.dirname(cachepath))
  end
  
  private
  
  def valid_file
    return false unless super
    if @file && !ImageBuilder.image_content_type?(@file.content_type)
      errors.add('file', 'must be an image')
      return false
    else
      return true
    end
  end
  
  def image_for_format(format=nil)
    if @file
      ImageBuilder.new(:file=>@file).transform!(format)
    elsif !new_record?
      @formats ||= {}
      @formats[format] ||= ImageBuilder.new(:path=>filepath, 
              :width=>self[:width], :height=>self[:height]).transform!(format)
    else
      raise StandardError, "No image to work on"
    end
  end
  
  def make_image(format)
    return nil unless format && (img = image_for_format(format))
    return nil if img.dummy?
    make_file(filepath(format),img)
  end
  
  def verify_format(format)
    if format.nil?
      format = 'full'
    end
    if IMAGEBUILDER_FORMAT[format]
      format
    else
      nil
    end
  end
end