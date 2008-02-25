=begin rdoc
Used by Image to store image data. See the documentation on this class for more information.

=== Attributes

Provides the following attributes/methods to Image :

size(mode)::    file size for the image at the given mode
ext::             file extension
content_type::    file content_type                
width(mode)::   image width in pixel for the given mode
height(mode)::  image height in pixel for the given mode

ImageContent also provides a +crop+ pseudo attribute to crop an image. See crop=.
=end
class ImageContent < DocumentContent
  before_validation_on_create :convert_file
  
  zafu_readable    :width, :height
  
  # Return a cropped image using the 'crop' hash with the top left corner position (:x, :y) and the width and height (:width, :heigt).
  def crop(format)
    original   = format[:original] || self.file
    x, y, w, h = format[:x].to_f, format[:y].to_f, format[:w].to_f, format[:h].to_f
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
    remove_mode_images if !new_record?
    img = image_for_mode(nil)
    self[:width ] = img.width
    self[:height] = img.height
  end
  
  # Return the size for an image at the given mode. If no mode is provided, 'full' is used.
  def size(mode=nil)
    mode = verify_mode(mode)
    if mode == 'full'
      super
    elsif mode
      if File.exist?(filepath(mode)) || make_image(mode)
        File.stat(filepath(mode)).size
      else
        nil
      end
    else
      nil
    end
  end
  
  # Return the width in pixels for an image at the given mode. If no mode is provided, 'full' is used.
  def width(mode=nil)
    mode = verify_mode(mode)
    if mode == 'full'
      self[:width]
    elsif mode
      if img = image_for_mode(mode)
        img.width
      else
        nil
      end
    else
      nil
    end
  end
  
  # Return the height in pixels for an image at the given mode. If no mode is provided, 'full' is used.
  def height(mode=nil)
    mode = verify_mode(mode)
    if mode == 'full'
      self[:height]
    elsif mode
      if img = image_for_mode(mode)
        img.height
      else
        nil
      end
    else
      nil
    end
  end
  
  # Image filename for the given mode. For example, 'bird_pv.jpg' is the name for 'pv' mode. The name without a mode or 'full' mode would be 'bird.jpg'
  def filename(mode=nil)
    mode = verify_mode(mode)
    if mode == 'full'
      super
    elsif mode
      "#{name}_#{mode}.#{ext}"
    else
      nil
    end
  end
  
  # Return a file with the data for the given mode. It is the receiver's responsability to close the file.
  def file(mode=nil)
    return nil if mode == 'full' # We only send full data when asked with mode is nil.
    mode = verify_mode(mode)
    if mode == 'full'
      if @file
        @file
      elsif File.exist?(filepath)
        File.new(filepath)
      else
        nil
      end
    elsif mode
      if File.exist?(filepath(mode)) || make_image(mode)
        File.new(filepath(mode))
      else
        nil
      end
    else
      nil
    end
  end
  
  # Used to remove formatted images when these images are cached in the public directory
  def remove_image(mode)
    return false unless (mode = verify_mode(mode)) && (mode != 'full')
    FileUtils::rm(filepath(mode)) if File.exist?(filepath(mode))
  end
  
  # Removes all images created by ImageBuilder for this image_content. This is used when the file changes or when the name changes.
  def remove_mode_images
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
  
  def verify_mode(mode)
    if mode.nil?
      mode = 'full'
    end
    if IMAGEBUILDER_FORMAT[mode]
      mode
    else
      nil
    end
  end
  
  def image_for_mode(mode=nil)
    if @file
      ImageBuilder.new(:file=>@file).transform!(mode)
    elsif !new_record?
      @modes ||= {}
      @modes[mode] ||= ImageBuilder.new(:path=>filepath, 
              :width=>self[:width], :height=>self[:height]).transform!(mode)
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
  
    def make_image(mode)
      return nil unless mode && (img = image_for_mode(mode))
      return nil if img.dummy?
      make_file(filepath(mode),img)
    end
end