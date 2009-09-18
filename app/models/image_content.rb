=begin rdoc
Used by Image to store image data. See the documentation on this class for more information.

=== Attributes

Provides the following attributes/methods to Image :

size(format)::    file size for the image using the given format
ext::             file extension
content_type::    file content_type
width(format)::   image width in pixel using the given format
height(format)::  image height in pixel using the given format

ImageContent also provides a +crop+ pseudo attribute to crop an image. See crop=.
=end
class ImageContent < DocumentContent
  before_validation_on_create :convert_file

  attr_public      :width, :height, :exif, :exif_gps_latitude, :exif_gps_longitude # FIXME: rubyless remove these and access ExifData

  attr_accessible  :content_type, :file, :crop

  def would_edit?(new_attrs)
    super || (new_attrs['crop'] && can_crop?(new_attrs['crop']))
  end

  def can_crop?(format)
    x, y, w, h = [format[:x].to_f, 0].max, [format[:y].to_f,0].max, [format[:w].to_f, width].min, [format[:h].to_f, height].min
    format[:max_value] || format[:format] || (x < width && y < height && w > 0 && h > 0) && !(x==0 && y==0 && w == width && h == height)
  end

  # Crop the image using the 'crop' hash with the top left corner position (:x, :y) and the width and height (:width, :heigt). Example:
  #   @node.crop = {:x=>10, :y=>10, :width=>30, :height=>60}
  # Be carefull as this method changes the current file. So you should make a backup version before croping the image (the popup editor displays a warning).
  def crop=(format)
    if can_crop?(format)
      # do crop
      if file = self.cropped_file(format)
        # crop can return nil, check first.
        self.file = file
      end
    end
  end


  # Return a cropped image using the 'crop' hash with the top left corner position (:x, :y) and the width and height (:width, :heigt).
  def cropped_file(format)
    original   = format[:original] || @loaded_file || self.file
    x, y, w, h = format[:x].to_f, format[:y].to_f, format[:w].to_f, format[:h].to_f
    new_type   = format[:format] ? EXT_TO_TYPE[format[:format].downcase][0] : nil
    max        = format[:max_value].to_f * (format[:max_unit] == 'Mb' ? 1024 : 1) * 1024

    # crop image
    img = ImageBuilder.new(:file=>original)
    img.crop!(x, y, w, h) if x && y && w && h
    img.format       = format[:format] if new_type && new_type != content_type
    img.max_filesize = max if format[:max_value] && max

    file = Tempfile.new(name)
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
    img = image_with_format(nil)
    self[:width ] = img.width
    self[:height] = img.height
    self[:exif_json] = img.exif.to_json rescue nil
  end

  # Return the size for an image at the given format.
  def size(format=nil)
    if format.nil? || format.size == :keep
      super
    else
      if File.exist?(filepath(format)) || make_image(format)
        File.stat(filepath(format)).size
      else
        nil
      end
    end
  end

  # Return the width in pixels for an image at the given format.
  def width(format=nil)
    if format.nil? || format.size == :keep
      self[:width]
    else
      if img = image_with_format(format)
        img.width
      else
        nil
      end
    end
  end

  # Return the height in pixels for an image at the given format.
  def height(format=nil)
    if format.nil? || format.size == :keep
      self[:height]
    else
      if img = image_with_format(format)
        img.height
      else
        nil
      end
    end
  end

  # Return a file with the data for the given format. It is the receiver's responsability to close the file.
  def file(format=nil)
    if format.nil? || format.size == :keep
      super
    else
      if File.exist?(filepath(format)) || make_image(format)
        File.new(filepath(format))
      else
        nil
      end
    end
  end

  def image_with_format(format=nil)
    if new_record? && @file
      ImageBuilder.new(:file=>@file).transform!(format)
    elsif !new_record?
      format   ||= Iformat['full']
      @formats ||= {}
      @formats[format[:name]] ||= ImageBuilder.new(:path=>filepath,
              :width=>self[:width], :height=>self[:height]).transform!(format)
    else
      raise StandardError, "No image to work on"
    end
  end

  def exif
    @exif ||= ExifData.new(self[:exif_json])
  end

  # FIXME: remove when RubyLess is here !
  def exif_gps_latitude
    exif.gps_latitude
  end

  # FIXME: remove when RubyLess is here !
  def exif_gps_longitude
    exif.gps_longitude
  end

  private
    def convert_file
      #if @file && @file.content_type =~ /image\/gif/
      #  # convert to png
      #  file  = @file
      #  @file = nil
      #  @file = cropped_file(:original => file, :format => 'png')
      #  self[:ext] = 'png'
      #end
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
      return nil unless img = image_with_format(format)
      return nil if img.dummy?
      make_file(filepath(format),img)
    end
end