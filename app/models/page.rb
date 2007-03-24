=begin rdoc
=== subclasses

Tag::       used to create collections of items.
Document::  contains data from uploaded files.
Image::     subclass of Document, contains image data that can be resized/viewed in the browser.
TextDocument::  subclass of Document, used by documents that can be edited online (scripts, text).
Template::  subclass of TextDocument. Contains the zafu code to make the look and feel of the site.
Skin::      subclass of Template. Contains other templates. The skin name must be unique throughout the site as it is used to identify the 'theme' of the site or parts of the site.
=end
class Page < Node
  class << self
    def parent_class
      Page
    end
  
    def select_classes
      list = subclasses.inject([]) do |list, k|
        unless Document == k || k.ancestors.include?(Document)
          list << k.to_s
        end
        list
      end.sort
      list.unshift 'Page'
    end
  end
  
  def klass
    self.class.to_s
  end
end