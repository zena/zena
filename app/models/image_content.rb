=begin rdoc
Used by Image to store image data. See the documentation on this class for more information.

=== Attributes

Provides the following attributes/methods to Image :

size(format)::    file size for the image at the given format
ext::             file extension
content_type::    file content_type                
width(format)::   image width in pixel for the given format
height(format)::  image height in pixel for the given format

ImageContent also provides a +crop+ pseudo attribute to crop an image. See crop=.
=end
class ImageContent < DocumentContent
  before_validation_on_create :convert_file
  
  zafu_readable    :width, :height
  
  # Return a cropped image using the 'crop' hash with the top left corner position (:x, :y) and the width and height (:width, :heigt).
  def crop(format)
    return if @file # we do not want to crop on file upload in case the crop params lie around in the user's form
    original   = format[:original] || self.file
    x, y, w, h = format[:x].to_i, format[:y].to_i, format[:w].to_i, format[:h].to_i
    new_type   = format[:format] ? EXT_TO_TYPE[format[:format].downcase][0] : nil
    max        = format[:max_value].to_f * (format[:max_unit] == 'Mb' ? 1024 : 1) * 1024
    
    # crop image
    img = ImageBuilder.new(:file=>original)
    img.crop!(x, y, w, h) if x && y && w && h
    img.format       = format[:format] if new_type && new_type != content_type
    img.max_filesize = max if format[:max_value] && max
    
    file = Tempfile.new(filename)
    File.open(file.path, "wb") { |f| f.syswrite(img.read) }

    ctype = EXT_TO_TYPE[img.format.downcase][0]
    fname = "#{name}.#{TYPE_TO_EXT[ctype][0]}"
    (class << file; self; end;).class_eval do
      alias local_path path if defined?(:path)
      define_method(:original_filename) { fname }
      define_method(:content_type) { ctype }
    end
    file
  end
  
  # Set content file, will refuse to accept the file if it is not an image.
  def file=(aFile)
    super
    return unless ImageBuilder.image_content_type?(aFile.content_type)
    remove_format_images if !new_record?
    img = image_for_format(nil)
    self[:width ] = img.width
    self[:height] = img.height
  end
  
  # Return the size for an image at the given format. If no format is provided, 'full' is used.
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
  
  # Return the width in pixels for an image at the given format. If no format is provided, 'full' is used.
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
  
  # Return the height in pixels for an image at the given format. If no format is provided, 'full' is used.
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
  
  # Image filename for the given format. For example, 'bird_pv.jpg' is the name for 'pv' format. The name without a format or 'full' format would be 'bird.jpg'
  def filename(format=nil)
    format = verify_format(format)
    if format == 'full'
      super
    elsif format
      "#{name}_#{format}.#{ext}"
    else
      nil
    end
  end
  
  # Return a file with the data for the given format. It is the receiver's responsability to close the file.
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
  
  # Used to remove formatted images when these images are cached in the public directory
  def remove_image(format)
    return false unless (format = verify_format(format)) && (format != 'full')
    FileUtils::rm(filepath(format)) if File.exist?(filepath(format))
  end
  
  # Removes all images created by ImageBuilder for this image_content. This is used when the file changes or when the name changes.
  def remove_format_images
    dir = File.dirname(filepath)
    if File.exist?(dir)
      Dir.foreach(dir) do |file|
        next if file =~ /^\./
        next if file == filename
        FileUtils::rm(File.join(dir,file))
      end
    end
    # FIXME: Remove cached images from the public directory.
    # TODO: test
    # FileUtils::rmtree(File.dirname(cachepath))
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
  
  private
    def convert_file
      if @file && @file.content_type =~ /image\/gif/
        # convert to png
        file  = @file
        @file = nil
        @file = crop(:original => file, :format => 'png')
        self[:ext] = 'png'
      end
    end
      
    def valid_file
      return false unless super
      if @file && !ImageBuilder.image_content_type?(@file.content_type)
        errors.add('file', 'must be an image')
        return false
      else
        return true
      end
    end
  
    def make_image(format)
      return nil unless format && (img = image_for_format(format))
      return nil if img.dummy?
      make_file(filepath(format),img)
    end
end