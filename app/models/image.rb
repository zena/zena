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

=== Content

Content (file data) is managed by the ImageContent. This class is responsible for storing the file and retrieving the data. It provides the following attributes to the Image :

c_size(format)::    file size for the image at the given format
c_ext::             file extension
c_content_type::    file content_type
c_width(format)::   image width in pixel for the given format
c_height(format)::  image height in pixel for the given format

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
  before_validation :image_before_validation

  class << self
    def accept_content_type?(content_type)
      ImageBuilder.image_content_type?(content_type)
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

  # filter attributes so there is no 'crop' with a new file
  def filter_attributes(attributes)
    attrs = super
    attrs.delete('c_crop') if attributes['c_file'] && attributes['c_crop']
    attrs
  end

  # Return the image file for the given format (see Image for information on format)
  def file(format=nil)
    version.file(format)
  end

  # Return the size of the image for the given format (see Image for information on format)
  def filesize(format=nil)
    version.filesize(format)
  end

  private
    def image_before_validation
      # Set image event date to when the photo was taken
      self[:event_at] ||= version.content.exif.date_time
    end
end
