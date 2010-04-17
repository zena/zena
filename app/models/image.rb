=begin rdoc
An Image is a Document with a file that we can view inline. An image can be displayed in various formats (defined through modes). These modes are defined for each Site through Iformat. Default modes:

  'tiny' => { :size=>:force, :width=>16,  :height=>16,                },
  'mini' => { :size=>:force, :width=>32,  :ratio=>1.0,                },
  'pv'   => { :size=>:force, :width=>70,  :ratio=>1.0                 },
  'med'  => { :size=>:limit, :width=>280, :ratio=>2/3.0               },
  'top'  => { :size=>:force, :width=>280, :ratio=>2.0/3.0, :gravity=>Magick::NorthGravity},
  'mid'  => { :size=>:force, :width=>280, :ratio=>2.0/3.0, :gravity=>Magick::CenterGravity},
  'low'  => { :size=>:force, :width=>280, :ratio=>2.0/3.0, :gravity=>Magick::SouthGravity},
  'edit' => { :size=>:limit, :width=>400, :height=>400                },
  'std'  => { :size=>:limit, :width=>600, :ratio=>2/3.0               },
  'full' => { :size=>:keep },

To display an image with one of those formats, you use the 'img_tag' helper :

  img_tag(@node, :mode=>'med')

For more information on img_tag, have a look at ApplicationHelper#img_tag.

An image can be croped by changing the 'crop' pseudo attribute (see Image#crop= ) :

  @node.update_attributes(:c_crop=>{:x=>10, :y=>10, :width=>30, :height=>60})

=== Version

The version class used by images is the ImageVersion.

=== Storage

File data is managed by the Document Attachment. This class is responsible for storing the file and retrieving the data.

== Properties

These properties are added to Images :

 size(format)::    file size for the image at the given format
 width(format)::   image width in pixel for the given format
 height(format)::  image height in pixel for the given format

=== links

Default links for Image are:

icon_for::  become the unique 'icon' for the linked node.

Example on how to use 'icon' with ruby:
 @node.icon.img_tag('pv')   <= display the node's icon with the 'pv' (preview) format.

Same example in a zafu template:
 <r:img src='icon' format='pv'/>

or to create a link to the article using the icon:
 <r:img src='icon' format='pv' href='self'/>

=end
class Image < Document
  property do |t|
    t.integer 'width'
    t.integer 'height'
    t.text    'exif_json'
  end
  safe_property         :width, :height
  safe_method           :exif => 'ExifData'

  before_validation     :image_before_validation

  class << self
    def accept_content_type?(content_type)
      Zena::Use::ImageBuilder.image_content_type?(content_type)
    end

    # This is a callback from acts_as_multiversioned
    def version_class
      ImageVersion
    end

    # Class list to which this class can change to
    def change_to_classes_for_form
      classes_for_form(:class => 'Image')
    end
  end

  # Return the width in pixels for an image at the given format.
  def width(format=nil)
    if format.nil? || format.size == :keep
      prop['width']
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
      prop['height']
    else
      if img = image_with_format(format)
        img.height
      else
        nil
      end
    end
  end

  # Return the Exchangeable Image Format (Exif).
  def exif
    ExifData.new(prop['exif_json'])
  end

  # Return the size of the image for the given format (see Image for information on format).
  def filesize(format=nil)
    version.filesize(format)
  end

  # Updaging image attributes and propreties. Accept also :file and :crop keys.
  def update_attributes(attributes)
    attributes.stringify_keys!
    # If file and crop attributes are both present when updating, make sur to run file= before crop=.
    if attributes['file'] && attributes['crop']
      file = attributes.delete('file')
      crop = attributes.delete('crop')
      super(attributes)
      self.file = file
      self.crop = crop
      save
    else
      super(attributes)
    end
  end

  # Set content file, will refuse to accept the file if it is not an image.
  def file=(file)
    if Zena::Use::ImageBuilder.image_content_type?(file.content_type)
      @new_image = super
      img = image_with_format(nil)
      prop['width' ] = img.width
      prop['height'] = img.height
      prop['exif_json'] = img.exif.to_json rescue nil
    end
  end

  # Return a file with the data for the given format. It is the receiver's responsability to close the file.
  def file(format=nil)
    if format.nil? || format.size == :keep
      super()
    else
      if File.exist?(self.filepath(format)) || make_image(format)
        File.new(self.filepath(format))
      else
        nil
      end
    end
  end

  def can_crop?(format)
    x, y, w, h = [format['x'].to_i, 0].max, [format['y'].to_i, 0].max, [format['w'].to_i, width].min, [format['h'].to_i, height].min
    (format['max_value'] && (format['max_value'].to_f * (format['max_unit'] == 'Mb' ? 1024 : 1) * 1024) < prop['size']) ||
    (format['format'] && format['format'] != prop['ext']) ||
    ((x < width && y < height && w > 0 && h > 0) && !(x==0 && y==0 && w == width && h == height))
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
    original   = format['original'] || @loaded_file || self.file
    x, y, w, h = format['x'].to_f, format['y'].to_f, format['w'].to_f, format['h'].to_f
    new_type   = format['format'] ? Zena::EXT_TO_TYPE[format['format'].downcase][0] : nil
    max        = format['max_value'].to_f * (format['max_unit'] == 'Mb' ? 1024 : 1) * 1024

    # crop image
    img = Zena::Use::ImageBuilder.new(:file=>original)
    img.crop!(x, y, w, h) if x && y && w && h
    img.format       = format['format'] if new_type && new_type != content_type
    img.max_filesize = max if format['max_value'] && max

    file = Tempfile.new(filename)
    File.open(file.path, "wb") { |f| f.syswrite(img.read) }

    ctype = Zena::EXT_TO_TYPE[img.format.downcase][0]
    fname = "#{filename}.#{Zena::TYPE_TO_EXT[ctype][0]}"
    uploaded_file(file, filename, ctype)
  end

  def can_crop?(format)
    x, y, w, h = [format['x'].to_i, 0].max, [format['y'].to_i, 0].max, [format['w'].to_i, width].min, [format['h'].to_i, height].min
    (format['max_value'] && (format['max_value'].to_f * (format['max_unit'] == 'Mb' ? 1024 : 1) * 1024) < prop['size']) ||
    (format['format'] && format['format'] != prop['ext']) ||
    ((x < width && y < height && w > 0 && h > 0) && !(x==0 && y==0 && w == width && h == height))
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
    original   = format['original'] || @loaded_file || self.file
    x, y, w, h = format['x'].to_f, format['y'].to_f, format['w'].to_f, format['h'].to_f
    new_type   = format['format'] ? Zena::EXT_TO_TYPE[format['format'].downcase][0] : nil
    max        = format['max_value'].to_f * (format['max_unit'] == 'Mb' ? 1024 : 1) * 1024

    # crop image
    img = Zena::Use::ImageBuilder.new(:file=>original)
    img.crop!(x, y, w, h) if x && y && w && h
    img.format       = format['format'] if new_type && new_type != content_type
    img.max_filesize = max if format['max_value'] && max

    file = Tempfile.new(filename)
    File.open(file.path, "wb") { |f| f.syswrite(img.read) }

    ctype = Zena::EXT_TO_TYPE[img.format.downcase][0]
    fname = "#{filename}.#{Zena::TYPE_TO_EXT[ctype][0]}"
    uploaded_file(file, filename, ctype)
  end

  private

    # Set image event date to when the photo was taken
    def image_before_validation
      self[:event_at] ||= self.exif.date_time
    end

    # Create a new image in File System with the new format
    def image_with_format(format=nil)
      if @new_image
        Zena::Use::ImageBuilder.new(:file => @new_image).transform!(format)
      elsif !new_record?
        format   ||= Iformat['full']
        @formats ||= {}
        @formats[format[:name]] ||= Zena::Use::ImageBuilder.new(:path => filepath,
                :width => prop['width'], :height => prop['height']).transform!(format)
      else
        raise StandardError, "No image to work on"
      end
    end

    # Create an image with the new format.
    def make_image(format)
      return nil unless img = image_with_format(format)
      return nil if img.dummy?
      make_file(filepath(format),img)
    end

    # Create a file without creating a Version and an Attachment.
    def make_file(path, data)
      FileUtils::mkpath(File.dirname(path)) unless File.exist?(File.dirname(path))
      File.open(path, "wb") { |f| f.syswrite(data.read) }
    end

    # Define 2 methods :original_filename and :content_type which are compulsory for creating new file.
    def uploaded_file(file, filename = nil, content_type = nil)
      (class << file; self; end;).class_eval do
        #alias local_path path if respond_to?(:path)  # FIXME: do we need this ?
        define_method(:original_filename) { filename }
        define_method(:content_type) { content_type }
      end
      file
    end

end
