=begin rdoc
An Image is a Document with a file that we can view inline. An image can be displayed in various formats. These formats are defined for each Site through ImageFormat (not implemented yet: use fixed formats for now). Until the ImageFormat class is implemented, you can use the following formats :

  'tiny' => { :size=>:force, :width=>15,  :height=>15,  :scale=>1.7   },
  'mini' => { :size=>:force, :width=>32,  :ratio=>1.0,  :scale=>1.3   },
  'pv'   => { :size=>:force, :width=>70,  :ratio=>1.0                 },
  'med'  => { :size=>:limit, :width=>280, :ratio=>2/3.0               },
  'top'  => { :size=>:force, :width=>280, :ratio=>2.0/3.0, :gravity=>Magick::NorthGravity},
  'mid'  => { :size=>:force, :width=>280, :ratio=>2.0/3.0, :gravity=>Magick::CenterGravity},
  'low'  => { :size=>:force, :width=>280, :ratio=>2.0/3.0, :gravity=>Magick::SouthGravity},
  'edit' => { :size=>:limit, :width=>400, :height=>400                },
  'std'  => { :size=>:limit, :width=>600, :ratio=>2/3.0               },
  'full' => { :size=>:keep },
  
To display an image with one of those formats, you use the 'img_tag' :

  @node.img_tag('med')
  
For more information on img_tag, have a look at ImageContent#img_tag.

An image can be croped by changing the 'crop' pseudo attribute (see Image#crop= ) :

  @node.update_attributes(:crop=>{:x=>10, :y=>10, :width=>30, :height=>60})

=== Version

The version class used by images is the ImageVersion.

=== Content

Content (file data) is managed by the ImageContent. This class is responsible for storing the file and retrieving the data. It provides the following attributes to the Image :

+c_size(format)+::  file size for the image at the given format
+c_ext+::   file extension
+c_width(format)+:: image width in pixel for the given format
+c_height(format)+:: image height in pixel for the given format

=end
class Image < Document
  link :icon_for, :class_name=>'Node', :as=>'icon'
  class << self
    def accept_content_type?(content_type)
      ImageBuilder.image_content_type?(content_type)
    end
  end
  
  # Crops an image. See ImageContent#crop for details on this method.
  def c_crop=(crop)
    x, y, w, h = crop[:x].to_i, crop[:y].to_i, crop[:w].to_i, crop[:h].to_i
    if (x >= 0 && y >= 0 && w <= c_width && h <= c_height) && !(x==0 && y==0 && w == c_width && h == c_height)
      # do crop
      redaction.redaction_content.crop = crop
    else
      # nothing to do: ignore this operation.
    end
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
  # This is a callback from acts_as_multiversioned
  def version_class
    ImageVersion
  end
end
